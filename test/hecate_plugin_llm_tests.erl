-module(hecate_plugin_llm_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Classification tests (pure logic, no mocking needed)
%%====================================================================

%% We test the internal classify logic indirectly via select_model/1
%% by mocking manage_providers:list_all_models/0.

-ifdef(TEST).

%%--------------------------------------------------------------------
%% select_model — Anthropic models
%%--------------------------------------------------------------------

select_haiku_for_fast_test() ->
    Models = [
        model(<<"claude-haiku-4-5-20251001">>, <<"claude">>, <<>>),
        model(<<"claude-sonnet-4-6-20260101">>, <<"claude">>, <<>>),
        model(<<"claude-opus-4-6-20260101">>, <<"claude">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"claude-haiku-4-5-20251001">>},
                     hecate_plugin_llm:select_model(#{capability => fast}))
    end).

select_sonnet_for_balanced_test() ->
    Models = [
        model(<<"claude-haiku-4-5-20251001">>, <<"claude">>, <<>>),
        model(<<"claude-sonnet-4-6-20260101">>, <<"claude">>, <<>>),
        model(<<"claude-opus-4-6-20260101">>, <<"claude">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"claude-sonnet-4-6-20260101">>},
                     hecate_plugin_llm:select_model(#{capability => balanced}))
    end).

select_opus_for_smart_test() ->
    Models = [
        model(<<"claude-haiku-4-5-20251001">>, <<"claude">>, <<>>),
        model(<<"claude-sonnet-4-6-20260101">>, <<"claude">>, <<>>),
        model(<<"claude-opus-4-6-20260101">>, <<"claude">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"claude-opus-4-6-20260101">>},
                     hecate_plugin_llm:select_model(#{capability => smart}))
    end).

%%--------------------------------------------------------------------
%% select_model — OpenAI models
%%--------------------------------------------------------------------

select_gpt4o_mini_for_fast_test() ->
    Models = [
        model(<<"gpt-4o-mini">>, <<"openai">>, <<>>),
        model(<<"gpt-4o">>, <<"openai">>, <<>>),
        model(<<"o3">>, <<"openai">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"gpt-4o-mini">>},
                     hecate_plugin_llm:select_model(#{capability => fast}))
    end).

select_o3_for_smart_test() ->
    Models = [
        model(<<"gpt-4o-mini">>, <<"openai">>, <<>>),
        model(<<"gpt-4o">>, <<"openai">>, <<>>),
        model(<<"o3">>, <<"openai">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"o3">>},
                     hecate_plugin_llm:select_model(#{capability => smart}))
    end).

%%--------------------------------------------------------------------
%% select_model — Local models (parameter-size based)
%%--------------------------------------------------------------------

select_small_local_for_fast_test() ->
    Models = [
        model(<<"phi-3:3.8b">>, <<"phi">>, <<"3.8B">>),
        model(<<"llama3:8b">>, <<"llama">>, <<"8B">>),
        model(<<"llama3:70b">>, <<"llama">>, <<"70B">>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"phi-3:3.8b">>},
                     hecate_plugin_llm:select_model(#{capability => fast}))
    end).

select_large_local_for_smart_test() ->
    Models = [
        model(<<"phi-3:3.8b">>, <<"phi">>, <<"3.8B">>),
        model(<<"llama3:8b">>, <<"llama">>, <<"8B">>),
        model(<<"llama3:70b">>, <<"llama">>, <<"70B">>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"llama3:70b">>},
                     hecate_plugin_llm:select_model(#{capability => smart}))
    end).

%%--------------------------------------------------------------------
%% select_model — Provider filtering
%%--------------------------------------------------------------------

filter_by_provider_test() ->
    Models = [
        model_with_provider(<<"claude-sonnet-4-6-20260101">>, <<"claude">>, <<>>, <<"anthropic">>),
        model_with_provider(<<"gpt-4o">>, <<"openai">>, <<>>, <<"openai">>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"gpt-4o">>},
                     hecate_plugin_llm:select_model(#{capability => balanced,
                                                      provider => <<"openai">>}))
    end).

%%--------------------------------------------------------------------
%% select_model — Edge cases
%%--------------------------------------------------------------------

no_models_returns_error_test() ->
    with_models([], fun() ->
        ?assertMatch({error, no_models},
                     hecate_plugin_llm:select_model(#{capability => fast}))
    end).

single_model_always_selected_test() ->
    Models = [model(<<"some-model">>, <<"unknown">>, <<>>)],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"some-model">>},
                     hecate_plugin_llm:select_model(#{capability => smart}))
    end).

%%--------------------------------------------------------------------
%% Google models
%%--------------------------------------------------------------------

select_gemini_flash_for_fast_test() ->
    Models = [
        model(<<"gemini-2.5-flash">>, <<"google">>, <<>>),
        model(<<"gemini-2.5-pro">>, <<"google">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"gemini-2.5-flash">>},
                     hecate_plugin_llm:select_model(#{capability => fast}))
    end).

select_gemini_pro_for_smart_test() ->
    Models = [
        model(<<"gemini-2.5-flash">>, <<"google">>, <<>>),
        model(<<"gemini-2.5-pro">>, <<"google">>, <<>>)
    ],
    with_models(Models, fun() ->
        ?assertMatch({ok, <<"gemini-2.5-pro">>},
                     hecate_plugin_llm:select_model(#{capability => smart}))
    end).

%%====================================================================
%% Helpers
%%====================================================================

model(Name, Family, ParamSize) ->
    #{name => Name, family => Family, parameter_size => ParamSize,
      context_length => 0, format => <<"api">>}.

model_with_provider(Name, Family, ParamSize, Provider) ->
    (model(Name, Family, ParamSize))#{provider => Provider}.

with_models(Models, Fun) ->
    meck:new(manage_providers, [non_strict]),
    meck:expect(manage_providers, list_all_models, fun() -> {ok, Models} end),
    try Fun()
    after meck:unload(manage_providers)
    end.

-endif.
