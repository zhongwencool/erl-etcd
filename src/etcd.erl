-module(etcd).

-export([set/3, set/2, set/1, get/1, delete/1, watch/2, watch_dir/2, get_current_peer/0]).
-export([test/0]).
-include("etcd.hrl").

%%%% set up a key with value with a TTL value(in seconds).
%%%% return is {ok, response string list from etcd}
-spec set(Key::list(), Value::list(), TTL::integer()) -> {ok, list()}| {fail, Reason::atom()}.
set(Key, Value, TTL) ->
    Opt = #etcd_modify_opts{key = Key, value = Value, ttl = TTL},
    gen_server:call(etcd_worker, {set, Opt}).

%%%% set up a key with value WITHOUT a TTL value.
%%%% return is {ok, response string list from etcd}
-spec set(Key::list(), Value::list()) -> {ok, list()} | {fail, Reason::atom()}.
set(Key, Value ) ->
    Opt = #etcd_modify_opts{key = Key, value = Value},
    gen_server:call(etcd_worker, {set, Opt}).

%%%% MasterMode, allow all parameters
%%%% return is {ok, response string list from etcd}
-spec set(Opts::#etcd_modify_opts{}) -> {ok, list()}| {fail, Reason::atom()}.
set(Opts) ->
    gen_server:call(etcd_worker, {set, Opts}).

%%%% get the value of a key/dir or just input with an etcd_read_opts.
%%%% return is {ok, response string list from etcd}
%%%% if the key doesn't exist, return {fail, not_found}
-spec get(KeyOrOpts::list() | #etcd_read_opts{}) -> {ok, list()}| {fail, Reason::atom()}.
get(KeyOrOpts) ->
    case is_record(KeyOrOpts, etcd_read_opts) of
        true ->
            gen_server:call(etcd_worker, {get, KeyOrOpts});
        false ->
            Opt = #etcd_read_opts{key = KeyOrOpts},
            gen_server:call(etcd_worker, {get, Opt})
    end.

%%%% delete the value of a key/dir or just input with an etcd_modify_opts.
%%%% return is {ok, response string list from etcd}
%%%% if the key doesn't exist, it will return {ok, _} as well.
-spec delete(KeyOrOpts::list() | #etcd_modify_opts{}) -> {ok, list()}| {fail, Reason::atom()}.
delete(KeyOrOpts) ->
    case is_record(KeyOrOpts, etcd_modify_opts) of
        true ->
            gen_server:call(etcd_worker, {delete, KeyOrOpts});
        false ->
            Opt = #etcd_modify_opts{key = KeyOrOpts},
            gen_server:call(etcd_worker, {delete, Opt})
    end.

%%% wait for the key changing event asynchronously
%%% when the key is changed, Callback function will be called,
%%% and the input will be the response string from etcd.
%%% the Callback should return ok to continue waiting, or stop to exit the waiting.
%%% Alarm: This API won't work for dir
-spec watch(KeyOrOpts::list() | #etcd_read_opts{}, Callback::fun((list())->(ok|stop))) -> ok.
watch(KeyOrOpts, Callback) ->
    Opts = case is_record(KeyOrOpts, etcd_read_opts) of
        true -> KeyOrOpts;
        false ->
            #etcd_read_opts{key = KeyOrOpts, modified_index = undefined}
    end,
    gen_server:cast(etcd_worker, {watch, Opts, Callback}).

%%% Wait for the dir changing event asynchronously.
%%% when the any key in the dir is changed, Callback function will be called,
%%% and the input will be the response string from etcd.
%%% the Callback should return ok to continue waiting, or stop to exit the waiting.
-spec watch_dir(KeyOrOpts::list()| #etcd_read_opts{}, Callback::fun((list())->(ok|stop))) -> ok.
watch_dir(KeyOrOpts, Callback) ->
    Opts = case is_record(KeyOrOpts, etcd_read_opts) of
        true -> KeyOrOpts;
        false ->
            #etcd_read_opts{key = KeyOrOpts, modified_index = undefined, recursive = true}
           end,
    gen_server:cast(etcd_worker, {watch, Opts, Callback}).

get_current_peer() ->
    gen_server:call(etcd_worker, {peer}).

