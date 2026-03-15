%%% @doc Delivery artifact templates for code generation.
%%%
%%% Generates CI/CD workflows, Dockerfiles, release workflows,
%%% and package scripts based on plugin type (in_vm or container).
%%%
%%% Also provides bump_version/1 for updating version strings
%%% across manifest.json, .app.src, and rebar.config.
%%% @end
-module(hecate_plugin_codegen_delivery).

-export([generate/1, bump_version/1]).

-import(hecate_plugin_codegen, [fmt/2, s/1, write_files/1]).

%% ===================================================================
%% generate/1 -- Create delivery artifacts based on plugin type
%% ===================================================================

-spec generate(map()) -> {ok, [string()]}.
generate(#{plugin_name := Name, plugin_type := Type} = Opts) ->
    OutDir = maps:get(output_dir, Opts, "."),
    OtpVsn = s(maps:get(otp_version, Opts, <<"27">>)),
    Port = s(maps:get(port, Opts, <<"4444">>)),
    AppName = hecate_plugin_codegen:app_atom_name(Name),
    case Type of
        in_vm -> generate_in_vm(OutDir, AppName, OtpVsn);
        container -> generate_container(OutDir, AppName, OtpVsn, Port)
    end.

generate_in_vm(OutDir, AppName, OtpVsn) ->
    Files = [
        {filename:join([OutDir, ".github", "workflows", "ci.yml"]),
         tpl_ci_yml(AppName, OtpVsn)},
        {filename:join([OutDir, ".github", "workflows", "release.yml"]),
         tpl_release_yml(AppName, OtpVsn)},
        {filename:join([OutDir, "scripts", "package.sh"]),
         tpl_package_sh(AppName)}
    ],
    {ok, Written} = write_files(Files),
    %% Make package.sh executable
    ScriptPath = filename:join([OutDir, "scripts", "package.sh"]),
    case filelib:is_regular(ScriptPath) of
        true -> file:change_mode(ScriptPath, 8#755);
        false -> ok
    end,
    {ok, Written}.

generate_container(OutDir, AppName, OtpVsn, Port) ->
    Files = [
        {filename:join([OutDir, ".github", "workflows", "ci.yml"]),
         tpl_ci_yml(AppName, OtpVsn)},
        {filename:join([OutDir, "Dockerfile"]),
         tpl_dockerfile(AppName, OtpVsn, Port)},
        {filename:join([OutDir, ".github", "workflows", "docker.yml"]),
         tpl_docker_yml(AppName, OtpVsn)}
    ],
    write_files(Files).

%% ===================================================================
%% bump_version/1 -- Update version strings in-place
%% ===================================================================

-spec bump_version(map()) -> ok | {error, term()}.
bump_version(#{version := Version, output_dir := Dir} = Opts) ->
    Vsn = s(Version),
    Changelog = s(maps:get(changelog, Opts, <<>>)),
    %% Update manifest.json
    update_file(filename:join(Dir, "manifest.json"),
                "\"version\": \"[^\"]*\"",
                "\"version\": \"" ++ Vsn ++ "\""),
    %% Update .app.src — find any .app.src under src/
    case filelib:wildcard(filename:join([Dir, "**", "*.app.src"])) of
        [AppSrc | _] ->
            update_file(AppSrc, "{vsn, \"[^\"]*\"}", "{vsn, \"" ++ Vsn ++ "\"}");
        [] -> ok
    end,
    %% Update rebar.config release version
    RebarConfig = filename:join(Dir, "rebar.config"),
    case filelib:is_regular(RebarConfig) of
        true ->
            update_file(RebarConfig,
                        "{release, \\{[^,]*, \"[^\"]*\"\\}",
                        fun(Match) ->
                            re:replace(Match, "\"[^\"]*\"\\}", "\"" ++ Vsn ++ "\"}", [{return, list}])
                        end);
        false -> ok
    end,
    %% Append to CHANGELOG.md
    case Changelog of
        "" -> ok;
        _ ->
            ChangelogPath = filename:join(Dir, "CHANGELOG.md"),
            Entry = io_lib:format("\n## ~s\n\n- ~s\n", [Vsn, Changelog]),
            case filelib:is_regular(ChangelogPath) of
                true ->
                    {ok, Old} = file:read_file(ChangelogPath),
                    ok = file:write_file(ChangelogPath, [Old, Entry]);
                false ->
                    Header = io_lib:format("# Changelog\n~s", [Entry]),
                    ok = file:write_file(ChangelogPath, Header)
            end
    end,
    ok.

%% ===================================================================
%% CI workflow template
%% ===================================================================

tpl_ci_yml(_AppName, OtpVsn) ->
    fmt(
        "name: CI\n"
        "\n"
        "on:\n"
        "  push:\n"
        "    branches: [main]\n"
        "  pull_request:\n"
        "    branches: [main]\n"
        "\n"
        "jobs:\n"
        "  build:\n"
        "    runs-on: ubuntu-latest\n"
        "    container:\n"
        "      image: erlang:~s\n"
        "    steps:\n"
        "      - uses: actions/checkout@v4\n"
        "      - name: Restore rebar3 cache\n"
        "        uses: actions/cache@v4\n"
        "        with:\n"
        "          path: |\n"
        "            ~~/.cache/rebar3\n"
        "            _build\n"
        "          key: ${{ runner.os }}-rebar3-${{ hashFiles('rebar.lock') }}\n"
        "      - name: Compile\n"
        "        run: rebar3 compile\n"
        "      - name: EUnit\n"
        "        run: rebar3 eunit\n"
        "      - name: Dialyzer\n"
        "        run: rebar3 dialyzer\n",
        [OtpVsn]).

%% ===================================================================
%% Dockerfile template (container only)
%% ===================================================================

tpl_dockerfile(AppName, OtpVsn, Port) ->
    fmt(
        "# Stage 1: Build\n"
        "FROM erlang:~s-alpine AS builder\n"
        "\n"
        "RUN apk add --no-cache git build-base\n"
        "\n"
        "WORKDIR /app\n"
        "COPY rebar.config rebar.lock ./\n"
        "RUN rebar3 compile\n"
        "\n"
        "COPY . .\n"
        "RUN rebar3 as prod release\n"
        "\n"
        "# Stage 2: Runtime\n"
        "FROM alpine:3.22\n"
        "\n"
        "RUN apk add --no-cache openssl ncurses-libs libstdc++\n"
        "\n"
        "WORKDIR /app\n"
        "COPY --from=builder /app/_build/prod/rel/~s ./\n"
        "\n"
        "ENV PORT=~s\n"
        "EXPOSE ~s\n"
        "\n"
        "HEALTHCHECK --interval=30s --timeout=5s --retries=3 \\\\\n"
        "  CMD wget -qO- http://localhost:~s/health || exit 1\n"
        "\n"
        "ENTRYPOINT [\"/app/bin/~s\"]\n"
        "CMD [\"foreground\"]\n",
        [OtpVsn, AppName, Port, Port, Port, AppName]).

%% ===================================================================
%% Docker build workflow template (container only)
%% ===================================================================

tpl_docker_yml(_AppName, _OtpVsn) ->
    fmt(
        "name: Docker\n"
        "\n"
        "on:\n"
        "  push:\n"
        "    branches: [main]\n"
        "    tags: ['v*']\n"
        "\n"
        "env:\n"
        "  REGISTRY: ghcr.io\n"
        "  IMAGE_NAME: ${{ github.repository }}\n"
        "\n"
        "jobs:\n"
        "  build:\n"
        "    runs-on: ubuntu-latest\n"
        "    permissions:\n"
        "      contents: read\n"
        "      packages: write\n"
        "    steps:\n"
        "      - uses: actions/checkout@v4\n"
        "      - name: Log in to Container registry\n"
        "        uses: docker/login-action@v3\n"
        "        with:\n"
        "          registry: ${{ env.REGISTRY }}\n"
        "          username: ${{ github.actor }}\n"
        "          password: ${{ secrets.GITHUB_TOKEN }}\n"
        "      - name: Extract metadata\n"
        "        id: meta\n"
        "        uses: docker/metadata-action@v5\n"
        "        with:\n"
        "          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}\n"
        "          tags: |\n"
        "            type=ref,event=branch\n"
        "            type=semver,pattern={{version}}\n"
        "            type=sha\n"
        "      - name: Set up Docker Buildx\n"
        "        uses: docker/setup-buildx-action@v3\n"
        "      - name: Build and push\n"
        "        uses: docker/build-push-action@v5\n"
        "        with:\n"
        "          context: .\n"
        "          push: true\n"
        "          tags: ${{ steps.meta.outputs.tags }}\n"
        "          labels: ${{ steps.meta.outputs.labels }}\n"
        "          cache-from: type=gha\n"
        "          cache-to: type=gha,mode=max\n"
        "          platforms: linux/amd64\n",
        []).

%% ===================================================================
%% Release workflow template (in_vm only)
%% ===================================================================

tpl_release_yml(AppName, OtpVsn) ->
    fmt(
        "name: Release\n"
        "\n"
        "on:\n"
        "  push:\n"
        "    tags: ['v*']\n"
        "\n"
        "permissions:\n"
        "  contents: write\n"
        "\n"
        "jobs:\n"
        "  release:\n"
        "    runs-on: ubuntu-latest\n"
        "    container:\n"
        "      image: erlang:~s\n"
        "    steps:\n"
        "      - uses: actions/checkout@v4\n"
        "      - name: Build release\n"
        "        run: |\n"
        "          rebar3 as prod tar\n"
        "      - name: Package plugin\n"
        "        run: scripts/package.sh\n"
        "      - name: Create GitHub Release\n"
        "        uses: softprops/action-gh-release@v2\n"
        "        with:\n"
        "          files: _build/prod/rel/~s/*.tar.gz\n"
        "          generate_release_notes: true\n",
        [OtpVsn, AppName]).

%% ===================================================================
%% Package script template (in_vm only)
%% ===================================================================

tpl_package_sh(AppName) ->
    fmt(
        "#!/bin/sh\n"
        "set -eu\n"
        "\n"
        "# Build a release tarball for plugin distribution\n"
        "echo \"Building release for ~s...\"\n"
        "rebar3 as prod tar\n"
        "\n"
        "TARBALL=$(find _build/prod/rel -name '*.tar.gz' | head -1)\n"
        "if [ -z \"$TARBALL\" ]; then\n"
        "  echo \"ERROR: No tarball found\" >&2\n"
        "  exit 1\n"
        "fi\n"
        "\n"
        "echo \"Package ready: $TARBALL\"\n",
        [AppName]).

%% ===================================================================
%% Internal helpers
%% ===================================================================

update_file(Path, Pattern, Replacement) when is_list(Replacement) ->
    case file:read_file(Path) of
        {ok, Content} ->
            Updated = re:replace(Content, Pattern, Replacement, [{return, binary}]),
            ok = file:write_file(Path, Updated);
        _ -> ok
    end;
update_file(Path, Pattern, ReplaceFun) when is_function(ReplaceFun, 1) ->
    case file:read_file(Path) of
        {ok, Content} ->
            case re:run(Content, Pattern, [{capture, first, list}]) of
                {match, [Match]} ->
                    Replaced = ReplaceFun(Match),
                    Updated = binary:replace(Content,
                                           list_to_binary(Match),
                                           list_to_binary(Replaced)),
                    ok = file:write_file(Path, Updated);
                nomatch -> ok
            end;
        _ -> ok
    end.
