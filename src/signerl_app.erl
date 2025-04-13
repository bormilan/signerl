%%%-------------------------------------------------------------------
%% @doc signerl public API
%% @end
%%%-------------------------------------------------------------------

-module(signerl_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    signerl_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
