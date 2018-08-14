-module(etcd_watch_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1, add_child/2, stop_child/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

add_child(Opts, Callback) ->
    supervisor:start_child(?MODULE, [Opts, Callback]).

stop_child(Pid) ->
    supervisor:terminate_child(?MODULE, Pid).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

init([]) ->
    RestartStrategy = simple_one_for_one,
    MaxRestarts = 600,
    MaxSecondsBetweenRestarts = 60,
    
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    
    Restart = transient,
    Shutdown = 2000,
    Type = worker,
    Module = etcd_watch_behaviour,
    Child =
        {Module, {Module, start_watch, []},
            Restart, Shutdown, Type, [Module]},
    
    {ok, {SupFlags, [Child]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
