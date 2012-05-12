%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2012-2012. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%
%%
-module(snmpa_ldb).

-behaviour(gen_server).

%% External exports
%% Avoid warning for local function demonitor/1 clashing with autoimported BIF.
-export([start_link/2, stop/0, verbosity/1]).

-export([
	 
	]).

%% gen_server callbacks
-export([init/1, 
	 handle_call/3, handle_cast/2, handle_info/2, 
	 terminate/2,
         code_change/3]).

-include("snmpa_internal.hrl").
-include("snmp_debug.hrl").
-include("snmp_verbosity.hrl").


-define(MK_TABLE_NAME(Pre, Post), 
	list_to_atom(atom_to_list(Pre) ++ "_" ++ atom_to_list(Post))).
-define(MK_CACHE_NAME(Name),  ?MK_TABLE_NAME(Name, cache)).
-define(MK_LOCKER_NAME(Name), ?MK_TABLE_NAME(Name, locker)).


-ifndef(default_verbosity).
-define(default_verbosity, silence).
-endif.

-ifdef(snmp_debug).
-define(GS_START_LINK(Name, Module, Opts),
        gen_server:start_link({local, Name}, ?MODULE,
                              [Module, Opts], [{debug,[trace]}])).
-else.
-define(GS_START_LINK(Name, Module, Opts),
        gen_server:start_link({local, Name}, ?MODULE,
                              [Module, Opts], [])).
-endif.


%%%-------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------
behaviour_info(callbacks) ->
    [{init,        4}, 
     {handle_insert,      1},
     {handle_delete,      2},
     {handle_lookup, 1},
     {, 2},
     {info,              1}, 
     {verbosity,         2}];
behaviour_info(_) ->
    undefined.

start_link(Name, Module, Opts) -> 
    ?d("start_link -> entry with"
       "~n   Name:   ~p"
       "~n   Module: ~p"
       "~n   Opts:   ~p", [Name, Module, Opts]),
    ?GS_START_LINK(Name, Module, Opts).


stop(Name) ->
    call(Name, stop).


subscribe_notifications(Name, Module) ->
    call(Name, {subscribe_notifications, Module}).

verbosity(Name, V) ->
    call(Name, {verbosity, V}).


variable_get(Name, Variable) ->
    {Module, State} = lock(Name, read),
    Reply = 
	try
	    begin
		Module:lookup(State, Variable)
	    end
	catch
	    T:E ->
		{error, {lookup_failed, T, E}}
	end,
    unlock(Name),
    Reply.


variable_set(Name, Variable, Value) ->
    {Alias, NClients, Module, State} = lock(Name, write),
    Reply = 
	try
	    begin
		Module:insert(State, Variable, Value)
	    end
	catch
	    T:E ->
		{error, {insert_failed, T, E}}
	end,
    unlock(Name),
    notify_clients(Alias, insert, NClients), 
    Reply.


notify_clients(_, _, []) ->
    ok;
%% <backward compat>
notify_clients(_DBAlias, Event, [{Client, Module}|Clients]) ->
    (catch Module:notify(Client, Event)),
    notify_clients(DBAlias, Event, Clients);
%% </backward compat>
notify_clients(DBAlias, Event, [{Client, Module, Extra}|Clients]) ->
    (catch Module:snmp_ldb_event(Client, DBAlias, Event, Extra)),
    notify_clients(DBAlias, Event, Clients).
    


%%%-------------------------------------------------------------------
%%% Callback functions from gen_server
%%%-------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%%--------------------------------------------------------------------
init([Name, Module, Opts]) ->
    case (catch do_init(Name, Module, Opts)) of
        {ok, State} ->
            ?vdebug("started",[]),
            {ok, State};
        {error, Reason} ->
            config_err("failed starting ~w: ~n~p", [Name, Reason]),
            {stop, {error, Reason}};
        Error ->
            config_err("failed starting ~w: ~n~p", [Name, Error]),
            {stop, {error, Error}}
    end.


do_init(Name, Module, Opts) ->
    process_flag(priority, get_prio(Opts)),
    process_flag(trap_exit, true),
    put(sname, sname(Name)),
    put(verbosity, get_verbosity(Opts)),
    ?vlog("starting",[]),
    case Module:open(#state{storage_module = Module}, Opts) of
	{ok, State} ->
	    {ok, State};
	{error, _} = Error ->
	    {stop, Error}
    end.


%%-----------------------------------------------------------------
%% Interface functions.
%%-----------------------------------------------------------------

%%-----------------------------------------------------------------
%% Functions for debugging.
%%-----------------------------------------------------------------
print()      -> call(print).
print(Table) -> call({print, Table, volatile}).

variable_get(Name, Db}) ->
    call({variable_get, Name, Db});
variable_get(Name) ->
    call({variable_get, Name, volatile}).

variable_set({Name, Db}, Val) ->
    call({variable_set, Name, Db, Val});
variable_set(Name, Val) ->
    call({variable_set, Name, volatile, Val}).

variable_inc({Name, Db}, N) ->
    cast({variable_inc, Name, Db, N});
variable_inc(Name, N) ->
    cast({variable_inc, Name, volatile, N}).

variable_delete({Name, Db}) ->
    call({variable_delete, Name, Db});
variable_delete(Name) ->
    call({variable_delete, Name, volatile}).


table_create({Name, Db}) ->
    call({table_create, Name, Db});
table_create(Name) ->
    call({table_create, Name, volatile}).

table_exists({Name, Db}) ->
    call({table_exists, Name, Db});
table_exists(Name) ->
    call({table_exists, Name, volatile}).

table_delete({Name, Db}) ->
    call({table_delete, Name, Db});
table_delete(Name) ->
    call({table_delete, Name, volatile}).

table_delete_row({Name, Db}, RowIndex) ->
    call({table_delete_row, Name, Db, RowIndex});
table_delete_row(Name, RowIndex) ->
    call({table_delete_row, Name, volatile, RowIndex}).

table_get_row({Name, Db}, RowIndex) ->
    call({table_get_row, Name, Db, RowIndex});
table_get_row(Name, RowIndex) ->
    call({table_get_row, Name, volatile, RowIndex}).

table_get_element({Name, Db}, RowIndex, Col) ->
    call({table_get_element, Name, Db, RowIndex, Col});
table_get_element(Name, RowIndex, Col) ->
    call({table_get_element, Name, volatile, RowIndex, Col}).

table_set_elements({Name, Db}, RowIndex, Cols) ->
    call({table_set_elements, Name, Db, RowIndex, Cols});
table_set_elements(Name, RowIndex, Cols) ->
    call({table_set_elements, Name, volatile, RowIndex, Cols}).

table_next({Name, Db}, RestOid) ->
    call({table_next, Name, Db, RestOid});
table_next(Name, RestOid) ->
    call({table_next, Name, volatile, RestOid}).

table_max_col({Name, Db}, Col) ->
    call({table_max_col, Name, Db, Col});
table_max_col(Name, Col) ->
    call({table_max_col, Name, volatile, Col}).

table_create_row({Name, Db}, RowIndex, Row) ->
    call({table_create_row, Name, Db,RowIndex, Row});
table_create_row(Name, RowIndex, Row) ->
    call({table_create_row, Name, volatile, RowIndex, Row}).
table_create_row(NameDb, RowIndex, Status, Cols) ->
    Row = table_construct_row(NameDb, RowIndex, Status, Cols),
    table_create_row(NameDb, RowIndex, Row).

match({Name, Db}, Pattern) ->
    call({match, Name, Db, Pattern});    
match(Name, Pattern) ->
    call({match, Name, volatile, Pattern}).


table_get(Table) ->
    table_get(Table, [], []).

table_get(Table, Idx, Acc) ->
    case table_next(Table, Idx) of
	endOfTable ->
            lists:reverse(Acc);
	NextIdx ->
	    case table_get_row(Table, NextIdx) of
		undefined ->
		    {error, {failed_get_row, NextIdx, lists:reverse(Acc)}};
		Row ->
		    NewAcc = [{NextIdx, Row}|Acc],
		    table_get(Table, NextIdx, NewAcc)
	    end
    end.


%%-----------------------------------------------------------------
%% Implements the variable functions.
%%-----------------------------------------------------------------
handle_call({variable_get, Name}, _From, State) -> 
    ?vlog("variable get: ~p [~p]", [Name]),
    {Reply, NewState} = insert(State, Name), 
    {reply, Reply, NewState};

handle_call({variable_set, Name, Db, Val}, _From, State) -> 
    ?vlog("variable ~p set [~p]: "
	  "~n   Val:  ~p",[Name, Db, Val]),
    {reply, insert(Db, Name, Val, State), State};

handle_call({variable_delete, Name, Db}, _From, State) -> 
    ?vlog("variable delete: ~p [~p]",[Name, Db]),
    {reply, delete(Db, Name, State), State};


%%-----------------------------------------------------------------
%% Implements the table functions.
%%-----------------------------------------------------------------
%% Entry in ets for a tablerow:
%% Key = {<tableName>, <(flat) list of indexes>}
%% Val = {{Row}, <Prev>, <Next>}
%% Where Prev and Next = <list of indexes>; "pointer to prev/next"
%% Each table is a double linked list, with a head-element, with
%% direct access to each individual element.
%% Head-el: Key = {<tableName>, first}
%% Operations:
%% table_create_row(<tableName>, <list of indexes>, <row>)   O(n)
%% table_delete_row(<tableName>, <list of indexes>)          O(1)
%% get(<tableName>, <list of indexes>, Col)            O(1)
%% set(<tableName>, <list of indexes>, Col, Val)       O(1)
%% next(<tableName>, <list of indexes>)   if Row exist O(1), else O(n)
%%-----------------------------------------------------------------
handle_call({table_create, Name, Db}, _From, State) ->
    ?vlog("table create: ~p [~p]",[Name, Db]),
    catch handle_delete(Db, Name, State),
    {reply, insert(Db, {Name, first}, {undef, first, first}, State), State};

handle_call({table_exists, Name, Db}, _From, State) ->
    ?vlog("table exist: ~p [~p]",[Name, Db]),
    Res =
	case lookup(Db, {Name, first}, State) of
	    {value, _} -> true;
	    undefined -> false
	end,
    ?vdebug("table exist result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_delete, Name, Db}, _From, State) ->
    ?vlog("table delete: ~p [~p]",[Name, Db]),
    catch handle_delete(Db, Name, State),
    {reply, true, State};

handle_call({table_create_row, Name, Db, Indexes, Row}, _From, State) ->
    ?vlog("table create row [~p]: "
	  "~n   Name:    ~p"
	  "~n   Indexes: ~p"
	  "~n   Row:     ~p",[Db, Name, Indexes, Row]),
    Res = 
	case catch handle_create_row(Db, Name, Indexes, Row, State) of
	    {'EXIT', _} -> false;
	    _ -> true
	end,
    ?vdebug("table create row result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_delete_row, Name, Db, Indexes}, _From, State) ->
    ?vlog("table delete row [~p]: "
	  "~n   Name:    ~p"
	  "~n   Indexes: ~p", [Db, Name, Indexes]),
    Res = 
	case catch handle_delete_row(Db, Name, Indexes, State) of
	    {'EXIT', _} -> false;
	    _ -> true
	end,
    ?vdebug("table delete row result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_get_row, Name, Db, Indexes}, _From, State) -> 
    ?vlog("table get row [~p]: "
	  "~n   Name:    ~p"
	  "~n   Indexes: ~p",[Db, Name, Indexes]),
    Res = case lookup(Db, {Name, Indexes}, State) of
	      undefined -> 
		  undefined;
	      {value, {Row, _Prev, _Next}} -> 
		  Row
	  end,
    ?vdebug("table get row result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_get_element, Name, Db, Indexes, Col}, _From, State) ->
    ?vlog("table ~p get element [~p]: "
	  "~n   Indexes: ~p"
	  "~n   Col:     ~p", [Name, Db, Indexes, Col]),
    Res = case lookup(Db, {Name, Indexes}, State) of
	      undefined -> undefined;
	      {value, {Row, _Prev, _Next}} -> {value, element(Col, Row)}
	  end,
    ?vdebug("table get element result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_set_elements, Name, Db, Indexes, Cols}, _From, State) ->
    ?vlog("table ~p set element [~p]: "
	  "~n   Indexes: ~p"
	  "~n   Cols:    ~p", [Name, Db, Indexes, Cols]),
    Res = 
	case catch handle_set_elements(Db, Name, Indexes, Cols, State) of
	    {'EXIT', _} -> false;
	    _ -> true
	end,
    ?vdebug("table set element result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_next, Name, Db, []}, From, State) ->
    ?vlog("table next: ~p [~p]",[Name, Db]),
    handle_call({table_next, Name, Db, first}, From, State);
    
handle_call({table_next, Name, Db, Indexes}, _From, State) ->
    ?vlog("table ~p next [~p]: "
	  "~n   Indexes: ~p",[Name, Db, Indexes]),
    Res = case lookup(Db, {Name, Indexes}, State) of
	      {value, {_Row, _Prev, Next}} -> 
		  if 
		      Next =:= first -> endOfTable;
		      true -> Next
		  end;
	      undefined -> 
		  table_search_next(Db, Name, Indexes, State)
	  end,
    ?vdebug("table next result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({table_max_col, Name, Db, Col}, _From, State) ->
    ?vlog("table ~p max col [~p]: "
	  "~n   Col: ~p",[Name, Db, Col]),
    Res = table_max_col(Db, Name, Col, 0, first, State),
    ?vdebug("table max col result: "
	    "~n   ~p",[Res]),
    {reply, Res, State};

handle_call({match, Name, Db, Pattern}, _From, State) ->
    ?vlog("match ~p [~p]:"
	"~n   Pat: ~p", [Name, Db, Pattern]),
    L1 = match(Db, Name, Pattern, State),
    {reply, lists:delete([undef], L1), State};

%% This check (that there is no backup already in progress) is also 
%% done in the master agent process, but just in case a user issues 
%% a backup call to this process directly, we add a similar check here. 
handle_call({backup, BackupDir}, From, 
	    #state{backup = undefined, dets = Dets} = State) ->
    ?vlog("backup: ~p",[BackupDir]),
    Pid = self(),
    V   = get(verbosity),
    case file:read_file_info(BackupDir) of
	{ok, #file_info{type = directory}} ->
	    BackupServer = 
		erlang:spawn_link(
		  fun() ->
			  put(sname, albs),
			  put(verbosity, V),
			  Dir   = filename:join([BackupDir]), 
			  #dets{tab = Tab} = Dets, 
			  Reply = handle_backup(Tab, Dir),
			  Pid ! {backup_done, Reply},
			  unlink(Pid)
		  end),	
	    ?vtrace("backup server: ~p", [BackupServer]),
	    {noreply, State#state{backup = {BackupServer, From}}};
	{ok, _} ->
	    {reply, {error, not_a_directory}, State};
	Error ->
	    {reply, Error, State}
    end;

handle_call({backup, _BackupDir}, _From, #state{backup = Backup} = S) ->
    ?vinfo("backup already in progress: ~p", [Backup]),
    {reply, {error, backup_in_progress}, S};

handle_call(dump, _From, #state{dets = Dets} = State) ->
    ?vlog("dump",[]),
    dets_sync(Dets),
    {reply, ok, State};

handle_call(info, _From, #state{dets = Dets, ets = Ets} = State) ->
    ?vlog("info",[]),
    Info = get_info(Dets, Ets),
    {reply, Info, State};

handle_call(print, _From, #state{dets = Dets, ets = Ets} = State) ->
    ?vlog("print",[]),
    L1 = ets:tab2list(Ets),
    L2 = dets_match_object(Dets, '_'),
    {reply, {{ets, L1}, {dets, L2}}, State};

handle_call({print, Table, Db}, _From, State) ->
    ?vlog("print: ~p [~p]", [Table, Db]),
    L = match(Db, Table, '$1', State),
    {reply, lists:delete([undef], L), State};

handle_call({register_notify_client, Client, Module}, _From, State) ->
    ?vlog("register_notify_client: "
	"~n   Client: ~p"
	"~n   Module: ~p", [Client, Module]),
    Nc = State#state.notify_clients,
    case lists:keysearch(Client,1,Nc) of
	{value,{Client,Mod}} ->
	    ?vlog("register_notify_client: already registered to: ~p",
		  [Module]),
	    {reply, {error,{already_registered,Mod}}, State};
	false ->
	    {reply, ok, State#state{notify_clients = [{Client,Module}|Nc]}}
    end;

handle_call({unregister_notify_client, Client}, _From, State) ->
    ?vlog("unregister_notify_client: ~p",[Client]),
    Nc = State#state.notify_clients,
    case lists:keysearch(Client,1,Nc) of
	{value,{Client,_Module}} ->
	    Nc1 = lists:keydelete(Client,1,Nc),
	    {reply, ok, State#state{notify_clients = Nc1}};
	false ->
	    ?vlog("unregister_notify_client: not registered",[]),
	    {reply, {error,not_registered}, State}
    end;

handle_call(stop, _From, State) ->
    ?vlog("stop",[]),
    {stop, normal, stopped, State};

handle_call(Req, _From, State) ->
    warning_msg("received unknown request: ~n~p", [Req]),
    Reply = {error, {unknown, Req}}, 
    {reply, Reply, State}.


handle_cast({variable_inc, Name, Db, N}, State) ->
    ?vlog("variable ~p inc"
	  "~n   N: ~p", [Name, N]),
    M = case lookup(Db, Name, State) of
	    {value, Val} -> Val;
	    _ -> 0 
	end,
    insert(Db, Name, M+N rem 4294967296, State),
    {noreply, State};
    
handle_cast({verbosity,Verbosity}, State) ->
    ?vlog("verbosity: ~p -> ~p",[get(verbosity),Verbosity]),
    put(verbosity,?vvalidate(Verbosity)),
    {noreply, State};
    
handle_cast(Msg, State) ->
    warning_msg("received unknown message: ~n~p", [Msg]),
    {noreply, State}.
    

handle_info({'EXIT', Pid, Reason}, #state{backup = {Pid, From}} = S) ->
    ?vlog("backup server (~p) exited for reason ~n~p", [Pid, Reason]),
    gen_server:reply(From, {error, Reason}),
    {noreply, S#state{backup = undefined}};

handle_info({'EXIT', Pid, Reason}, S) ->
    %% The only other processes we should be linked to are
    %% either the master agent or our supervisor, so die...
    {stop, {received_exit, Pid, Reason}, S};

handle_info({backup_done, Reply}, #state{backup = {_, From}} = S) ->
    ?vlog("backup done:"
	  "~n   Reply: ~p", [Reply]),
    gen_server:reply(From, Reply),
    {noreply, S#state{backup = undefined}};

handle_info(Info, State) ->
    warning_msg("received unknown info: ~n~p", [Info]),
    {noreply, State}.


terminate(Reason, State) ->
    ?vlog("terminate: ~p",[Reason]),
    close(State).


%%%-------------------------------------------------------------------
%%% Internal functions
%%%-------------------------------------------------------------------


%%----------------------------------------------------------
%% Code change
%%----------------------------------------------------------

%% downgrade
%%
%% code_change({down, _Vsn}, S1, downgrade_to_pre_4_7) ->
%%     #state{dets = D, ets = E, notify_clients = NC, backup = B} = S1,
%%     stop_backup_server(B),
%%     S2 = {state, D, E, NC},
%%     {ok, S2};

%% upgrade
%%
%% code_change(_Vsn, S1, upgrade_from_pre_4_7) ->
%%     {state, D, E, NC} = S1,
%%     S2 = #state{dets = D, ets = E, notify_clients = NC},
%%     {ok, S2};

code_change(_Vsn, State, _Extra) ->
    {ok, State}.


%%------------------------------------------------------------------
%% Storage backend interface/wrapper functions
%%------------------------------------------------------------------

open(#state{storage_module = Module} = State, Opts) ->
    try Module:open(Opts) of
	{ok, StorageState} ->
	    {ok, State#state{storage_state = StorageState}}
    catch
	T:Reason ->
	    error_msg("Open failed (~w): "
		      "~n   ~p", [T, Reason]),
	    {error, {T, Reason}}
    end.


close(#state{storage_module = Module, 
	     storage_state  = StorageState} = State) ->
    try Module:handle_close(StorageState) of
	ok ->
	    State#state{storage_state = undefined}
    catch
	T:Reason ->
	    error_msg("Close failed (~w): "
		      "~n   ~p", [T, Reason]),
	    State
    end.


insert(#state{storage_module = Module, 
	      storage_state  = StorageState} = State, Key, Value) ->
    try Module:handle_insert(StorageState, Key, Value) of
	{ok, NewStorageState} ->
	    {true, State#state{storage_state = NewStorageState}};	    
	ok ->
	    {true, State}
    catch
	T:Reason ->
	    error_msg("Insert failed (~w) for ~p with value ~p: "
		      "~n   ~p", [T, Key, Value, Reason]),
	    {false, State}	    
    end.


delete(#state{storage_module = Module, 
	      storage_state  = StorageState} = State, Key) ->
    try Module:handle_delete(StorageState, Key) of
	{ok, NewStorageState} ->
	    {true, State#state{storage_state = NewStorageState}};	    
	ok ->
	    {true, State}
    catch
	T:Reason ->
	    error_msg("Delete failed (~w) for ~p: "
		      "~n   ~p", [T, Key, Reason]),
	    {false, State}
    end.


lookup(#state{storage_module = Module, 
	      storage_state  = StorageState} = State, Key) ->
    try Module:handle_lookup(StorageState, Key) of
	undefined ->
	    {undefined, State};
	{undefined, NewStorageState} ->
	    {undefined, State#state{storage_state = NewStorageState}};
	{ok, Value} ->
	    {{value, Value}, State};
	{ok, Value, NewStorageState} ->
	    {{value, Value}, State#state{storage_state = NewStorageState}}
    catch
	T:Reason ->
	    error_msg("Lookup failed (~w) for ~p: "
		      "~n   ~p", [T, Key, Reason]),
	    {undefined, State}
    end.


match(#state{storage_module = Module, 
	     storage_state  = StorageState} = State, Pattern) ->
    try Module:handle_match(StorageState, Pattern) of
	{ok, Match} ->
	    {Match, State};
	{ok, Match, NewStorageState} ->
	    {Match, State#state{storage_state = NewStorageState}}
    catch
	T:Reason ->
	    error_msg("Match failed (~w) for ~p: "
		      "~n   ~p", [T, Pattern, Reason]),
	    []
    end.


%%------------------------------------------------------------------
%% This functions retrieves option values from the Options list.
%%------------------------------------------------------------------

get_prio(Opts) ->
    get_opt(prio, Opts, normal).

get_verbosity(Opts) ->
    get_opt(verbosity, Opts, ?default_verbosity).

get_opt(Key, Opts, Def) ->
    snmp_misc:get_option(Key, Opts, Def).


%%------------------------------------------------------------------

%% info_msg(F, A) ->
%%     ?snmpa_info("Target cache server: " ++ F, A).

warning_msg(F, A) ->
    ?snmpa_warning("Target cache server: " ++ F, A).

error_msg(F, A) ->
    ?snmpa_error("Target cache server: " ++ F, A).

%% ---

%% user_err(F, A) ->
%%     snmpa_error:user_err(F, A).

config_err(F, A) ->
    snmpa_error:config_err(F, A).

%% error(Reason) ->
%%     throw({error, Reason}).


%% ----------------------------------------------------------------

call(Req) ->
    gen_server:call(?SERVER, Req, infinity).

cast(Msg) ->
    gen_server:cast(?SERVER, Msg).
