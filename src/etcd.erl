-module(etcd).

-export([
    set/3, set/2, set/1, get/1, delete/1, list_dir/1,
    create_with_auto_increase_key/1,
    watch/3, watch_dir/3, stop_watch/1,
    get_current_peer/0
]).
-include("etcd.hrl").

%%%% set up a key with value with a TTL value(in seconds).
%%%% return is {ok, response string list from etcd}
-spec set(Key :: list(), Value :: list(), TTL :: integer()) -> {ok, list()}| {fail, Reason :: atom()}.
set(Key, Value, TTL) ->
    Opt = #etcd_modify_opts{key = Key, value = Value, ttl = TTL},
    case get_current_peer() of
        {ok, Peer} -> etcd_worker:etcd_action(set, Peer ++ "/v2", Opt);
        Err -> Err
    end.

%%%% set up a key with value WITHOUT a TTL value.
%%%% return is {ok, response string list from etcd}
-spec set(Key :: list(), Value :: list()) -> {ok, list()} | {fail, Reason :: atom()}.
set(Key, Value) ->
    Opt = #etcd_modify_opts{key = Key, value = Value},
    case get_current_peer() of
        {ok, Peer} -> etcd_worker:etcd_action(set, Peer ++ "/v2", Opt);
        Err -> Err
    end.

%%%% MasterMode, allow all parameters
%%%% return is {ok, response string list from etcd}
-spec set(Opts :: #etcd_modify_opts{}) -> {ok, list()}| {fail, Reason :: atom()}.
set(Opts) ->
    case get_current_peer() of
        {ok, Peer} -> etcd_worker:etcd_action(set, Peer ++ "/v2", Opts);
        Err -> Err
    end.

%%%% MasterMode, allow all parameters
%%%% return is {ok, response string list from etcd}
create_with_auto_increase_key(Opts) ->
    case get_current_peer() of
        {ok, Peer} -> etcd_worker:etcd_action(create, Peer ++ "/v2", Opts);
        Err -> Err
    end.

%%%% get the value of a key/dir or just input with an etcd_read_opts.
%%%% return is {ok, response string list from etcd}
%%%% if the key doesn't exist, return {fail, not_found}
-spec get(KeyOrOpts :: list() | #etcd_read_opts{}) -> {ok, list()}| {fail, Reason :: atom()}.
get(KeyOrOpts) ->
    Opts = case is_record(KeyOrOpts, etcd_read_opts) of
               true ->
                   KeyOrOpts;
               false ->
                   #etcd_read_opts{key = KeyOrOpts}
           end,
    case get_current_peer() of
        {ok, Peer} -> etcd_worker:etcd_action(get, Peer ++ "/v2", Opts);
        Err -> Err
    end.

%%%% get the value of a key/dir or just input with an etcd_read_opts.
%%%% return is {ok, list of nodes under the dir} if success
%%%% if the key doesn't exist, return {fail, not_found}
%%%% if the key is not dir, reutrn {fail, not_dir}

%%% list of nodes will in format : [ PropListOfEtcdRetrunedNode ]
-spec list_dir(KeyOrOpts :: list() | #etcd_read_opts{}) -> {ok, list()}| {fail, Reason :: atom()}.
list_dir(KeyOrOpts) ->
    Opts = case is_record(KeyOrOpts, etcd_read_opts) of
               true ->
                   KeyOrOpts;
               false ->
                   #etcd_read_opts{key = KeyOrOpts}
           end,
    case get_current_peer() of
        {ok, Peer} ->
            case etcd_worker:etcd_action(get, Peer ++ "/v2", Opts) of
                {ok, GetResult} ->
                    case jiffy:decode(GetResult) of
                        {RetPropList} ->
                            {NodeProp} = proplists:get_value(<<"node">>, RetPropList),
                            IsDir = proplists:get_value(<<"dir">>, NodeProp, false),
                            case IsDir of
                                true ->
                                    Nodes = proplists:get_value(<<"nodes">>, NodeProp),
                                    RetrivedNodes = case Nodes of
                                                        undefined ->
                                                            [];
                                                        _ ->
                                                            [Node || {Node} <- Nodes]
                                                    end,
                                    {ok, RetrivedNodes};
                                false ->
                                    {fail, not_dir}
                            end
                    end;
                _ ->
                    {fail, not_found}
            end;
        Err -> Err
    end.

%%%% delete the value of a key/dir or just input with an etcd_modify_opts.
%%%% return is {ok, response string list from etcd}
%%%% if the key doesn't exist, it will return {ok, _} as well.
-spec delete(KeyOrOpts :: list() | #etcd_modify_opts{}) -> {ok, list()}| {fail, Reason :: atom()}.
delete(KeyOrOpts) ->
    Opts = case is_record(KeyOrOpts, etcd_modify_opts) of
               true ->
                   KeyOrOpts;
               false ->
                   #etcd_modify_opts{key = KeyOrOpts}
           end,
    case get_current_peer() of
        {ok, Peer} -> etcd_worker:etcd_action(delete, Peer ++ "/v2", Opts);
        Err -> Err
    end.

%%% wait for the key changing event asynchronously
%%% when the key is changed, Callback function will be called,
%%% and the input will be the response string from etcd.
%%% the Callback should return ok to continue waiting, or stop to exit the waiting.
%%% Alarm: This API won't work for dir
watch(KeyOrOpts, Pid, Flag) ->
    Opts = case is_record(KeyOrOpts, etcd_read_opts) of
               true -> KeyOrOpts;
               false ->
                   #etcd_read_opts{key = KeyOrOpts, modified_index = undefined}
           end,
    gen_server:call(etcd_worker, {watch, Opts, Pid, Flag}).

%%% Wait for the dir changing event asynchronously.
%%% A pid is returned for termiating
%%% when the any key in the dir is changed, Callback function will be called,
%%% and the input will be the response string from etcd.
%%% the Callback should return ok to continue waiting, or stop to exit the waiting.
watch_dir(KeyOrOpts, Pid, Flag) ->
    Opts = case is_record(KeyOrOpts, etcd_read_opts) of
               true -> KeyOrOpts;
               false ->
                   #etcd_read_opts{key = KeyOrOpts, modified_index = undefined, recursive = true}
           end,
    gen_server:call(etcd_worker, {watch, Opts, Pid, Flag}).

%%% stop watching
-spec stop_watch(Pid :: pid()) -> ok|{error, term()}.
stop_watch(Pid) ->
    etcd_sup:stop_child(Pid).

get_current_peer() ->
    gen_server:call(etcd_worker, {peer}).

