%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Eric B Merritt <ericbmerritt@gmail.com>
%% @copyright Copyright 2012 Opscode, Inc.
-module(bkss_store_server).

-behaviour(gen_server).

%% API
-export([start_link/0,
         get_bucket_reference/1,
         create_bucket/1,
         bucket_list/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-include("internal.hrl").
-include_lib("bookshelf_store/include/bookshelf_store.hrl").

-define(SERVER, ?MODULE).
-define(AWAIT_TIMEOUT, 1000).

-record(state, {}).

%%%===================================================================
%%% Types
%%%===================================================================
-type state() :: record(state).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link() -> {ok, pid()} | ignore | {error, Error::term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec get_bucket_reference(bookshelf_store:bucket_name()) -> pid().
get_bucket_reference(BucketName) ->
    gproc:where(make_key(BucketName)).

-spec create_bucket(bookshelf_store:bucket_name()) -> pid().
create_bucket(BucketName) ->
    gen_server:call(?SERVER, {create_bucket, BucketName}).

-spec bucket_list() -> [bookshelf_store:bucket()].
bucket_list() ->
    gen_server:call(?SERVER, bucket_list).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

-spec init([]) -> {ok, state()}.
init([]) ->
    {ok,DiskStore} = opset:get_value(disk_store, ?BOOKSHELF_CONFIG),
    Store = bkss_store:new(bkss_fs, DiskStore),
    lists:foreach(fun(#bucket{name=BucketName}) ->
                          bkss_bucket_sup:start_child(BucketName)
                  end, bkss_store:bucket_list(Store)),
    {ok, #state{}}.

-spec handle_call(Request::term(), From::pid(), state()) ->
                         {reply, Reply::term(), state}.
handle_call({create_bucket, BucketName}, _From, State) ->
    case bkss_bucket_server:bucket_server_exists(BucketName) of
        true ->
            ok;
        false ->
            bkss_bucket_sup:start_child(BucketName)
    end,
    {Pid, _} = gproc:await(make_key(BucketName)),
    {reply, Pid, State};
handle_call(bucket_list, _From, State) ->
    {ok,DiskStore} = opset:get_value(disk_store, ?BOOKSHELF_CONFIG),
    Store = bkss_store:new(bkss_fs, DiskStore),
    {reply, bkss_store:bucket_list(Store), State}.


-spec handle_cast(Msg::term(), state()) ->
                         {noreply, state()}.

handle_cast(handle_cast_not_implemented, State) ->
    erlang:error(handle_cast_not_implemented),
    {noreply, State}.

-spec handle_info(Info::term(), state()) ->
                         {noreply, state()}.
handle_info(handle_info_not_implemented, State) ->
    erlang:error(handle_info_not_implemented),
    {noreply, State}.

-spec terminate(Reason::term(), state()) -> ok.
terminate(_Reason, _State) ->
    ok.

-spec code_change(OldVsn::term(), state(), Extra::term) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
-spec make_key(bookshelf_store:bucket_name()) -> term().
make_key(BucketName) ->
    {n, l, BucketName}.
