%%%-------------------------------------------------------------------
%%% @doc LLM access for plugins via the daemon's serve_llm domain.
%%%
%%% Provides capability-based model selection so plugins never
%%% hardcode model names. Delegates all LLM operations to the
%%% daemon's chat_to_llm and manage_providers modules.
%%%
%%% == Capabilities ==
%%%
%%% Models are classified into three tiers:
%%%
%%% - `fast' — Smallest, fastest models. Good for classification,
%%%   extraction, simple Q&amp;A. (e.g. Haiku, GPT-4o-mini, small local)
%%%
%%% - `balanced' — Mid-tier models. Good for most tasks: summarization,
%%%   code generation, analysis. (e.g. Sonnet, GPT-4o, medium local)
%%%
%%% - `smart' — Largest, most capable models. Good for complex reasoning,
%%%   planning, architecture. (e.g. Opus, o1/o3, large local)
%%%
%%% == Usage ==
%%%
%%% ```
%%% {ok, Model} = hecate_plugin_llm:select_model(#{capability => balanced}),
%%% {ok, Reply} = hecate_plugin_llm:chat(Model, [
%%%     #{role => <<"user">>, content => <<"Summarize this document">>}
%%% ]).
%%% '''
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_plugin_llm).

-export([select_model/1, list_models/0]).
-export([chat/2, chat/3, chat_stream/3]).

-type capability() :: fast | balanced | smart.

%%--------------------------------------------------------------------
%% @doc Select a model by capability tier.
%%
%% Queries the daemon's available models, classifies each by
%% capability, and returns the best match.
%%
%% Options:
%%   capability — fast | balanced | smart (required)
%%   provider   — binary(), restrict to a specific provider (optional)
%%
%% Returns the model name (binary) suitable for chat/2,3.
%% @end
%%--------------------------------------------------------------------
-spec select_model(#{capability := capability(), _ => _}) ->
    {ok, binary()} | {error, term()}.
select_model(#{capability := Cap} = Opts) ->
    case list_models() of
        {ok, Models} ->
            Filtered = maybe_filter_provider(Models, Opts),
            pick_best(Cap, Filtered);
        {error, _} = Err ->
            Err
    end.

%%--------------------------------------------------------------------
%% @doc List all models available through the daemon's providers.
%% @end
%%--------------------------------------------------------------------
-spec list_models() -> {ok, [map()]} | {error, term()}.
list_models() ->
    manage_providers:list_all_models().

%%--------------------------------------------------------------------
%% @doc Send a chat completion request.
%% @end
%%--------------------------------------------------------------------
-spec chat(binary(), list()) -> {ok, map()} | {error, term()}.
chat(Model, Messages) ->
    chat_to_llm:chat(Model, Messages).

%%--------------------------------------------------------------------
%% @doc Send a chat completion request with options.
%%
%% Opts may include telemetry fields: venture_id, division_id,
%% agent_id, task_id.
%% @end
%%--------------------------------------------------------------------
-spec chat(binary(), list(), map()) -> {ok, map()} | {error, term()}.
chat(Model, Messages, Opts) ->
    chat_to_llm:chat(Model, Messages, Opts).

%%--------------------------------------------------------------------
%% @doc Start a streaming chat completion.
%%
%% Returns {ok, Ref}. The calling process receives messages:
%%   {llm_chunk, Ref, ChunkMap}
%%   {llm_done, Ref, FinalMap}
%%   {llm_error, Ref, Reason}
%% @end
%%--------------------------------------------------------------------
-spec chat_stream(binary(), list(), map()) ->
    {ok, reference()} | {error, term()}.
chat_stream(Model, Messages, Opts) ->
    chat_to_llm:chat_stream(Model, Messages, Opts).

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

maybe_filter_provider(Models, #{provider := Provider}) ->
    [M || #{provider := P} = M <- Models, P =:= Provider];
maybe_filter_provider(Models, _) ->
    Models.

-spec pick_best(capability(), [map()]) -> {ok, binary()} | {error, no_models}.
pick_best(_Cap, []) ->
    {error, no_models};
pick_best(Cap, Models) ->
    Scored = [{score(Cap, M), M} || M <- Models],
    Sorted = lists:reverse(lists:keysort(1, Scored)),
    [{_Score, #{name := Name}} | _] = Sorted,
    {ok, Name}.

%% Score a model for a given capability tier.
%% Higher score = better match.
score(Cap, #{name := Name} = Model) ->
    Family = maps:get(family, Model, <<>>),
    ParamSize = maps:get(parameter_size, Model, <<>>),
    tier_score(Cap, classify(Name, Family, ParamSize)).

%% How well a model's tier matches the requested capability.
%% Exact match = 100, one tier away = 50, two tiers away = 10.
tier_score(fast, fast)         -> 100;
tier_score(fast, balanced)     -> 50;
tier_score(fast, smart)        -> 10;
tier_score(balanced, balanced) -> 100;
tier_score(balanced, fast)     -> 50;
tier_score(balanced, smart)    -> 50;
tier_score(smart, smart)       -> 100;
tier_score(smart, balanced)    -> 50;
tier_score(smart, fast)        -> 10.

%% Classify a model into a capability tier based on name and metadata.
-spec classify(binary(), binary(), binary()) -> capability().
classify(Name, Family, ParamSize) ->
    NameLower = string:lowercase(Name),
    FamilyLower = string:lowercase(Family),
    case classify_by_name(NameLower) of
        unknown -> classify_by_params(FamilyLower, ParamSize);
        Tier    -> Tier
    end.

%% Name-based classification for well-known model families.
classify_by_name(Name) ->
    Patterns = [
        %% Anthropic Claude
        {<<"haiku">>,       fast},
        {<<"sonnet">>,      balanced},
        {<<"opus">>,        smart},
        %% OpenAI
        {<<"gpt-4o-mini">>, fast},
        {<<"gpt-4.1-mini">>,fast},
        {<<"gpt-4.1-nano">>,fast},
        {<<"gpt-4o">>,      balanced},
        {<<"gpt-4.1">>,     balanced},
        {<<"o4-mini">>,     balanced},
        {<<"o3-mini">>,     balanced},
        {<<"o1-mini">>,     balanced},
        {<<"o3">>,          smart},
        {<<"o1">>,          smart},
        %% Google
        {<<"gemini-2.0-flash">>, fast},
        {<<"gemini-2.5-flash">>, fast},
        {<<"gemini-2.0-pro">>,   balanced},
        {<<"gemini-2.5-pro">>,   smart},
        %% Meta Llama
        {<<"llama-3.3">>,   balanced},
        {<<"llama-3.1">>,   balanced},
        %% Mistral
        {<<"mistral-small">>,  fast},
        {<<"mistral-medium">>, balanced},
        {<<"mistral-large">>,  smart},
        %% DeepSeek
        {<<"deepseek-r1">>,    smart},
        {<<"deepseek-v3">>,    balanced},
        %% Qwen
        {<<"qwen-2.5-coder">>,balanced},
        {<<"qwq">>,           smart}
    ],
    match_patterns(Name, Patterns).

match_patterns(_Name, []) ->
    unknown;
match_patterns(Name, [{Pattern, Tier} | Rest]) ->
    case binary:match(Name, Pattern) of
        nomatch -> match_patterns(Name, Rest);
        _       -> Tier
    end.

%% Fallback: classify by parameter size for local models.
classify_by_params(_Family, <<>>) ->
    balanced;
classify_by_params(_Family, ParamSize) ->
    case parse_param_billions(ParamSize) of
        B when B < 7.0   -> fast;
        B when B =< 34.0 -> balanced;
        _                 -> smart
    end.

%% Parse parameter size strings like <<"7B">>, <<"13B">>, <<"70B">>.
-spec parse_param_billions(binary()) -> float().
parse_param_billions(Bin) ->
    Str = string:uppercase(binary_to_list(Bin)),
    parse_param_split(string:split(Str, "B")).

parse_param_split([NumStr | _]) ->
    try list_to_float(NumStr)
    catch error:badarg -> parse_param_int(NumStr)
    end;
parse_param_split(_) ->
    7.0.

parse_param_int(NumStr) ->
    try float(list_to_integer(NumStr))
    catch error:badarg -> 7.0
    end.
