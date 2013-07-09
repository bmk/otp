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
-export([start_link/3, stop/1, verbosity/2]).
-export([variable_get/2, 
	 variable_set/3, 
	 variable_delete/2, 
	 variable_inc/3, 

	 table_create/2, table_exists/2, table_delete/2, 
	 table_create_row/4, table_create_row/5, 
	 table_delete_row/3, 
	 table_get_row/3, 
	 table_get_element/4, 
	 table_get_elements/4, 
	 table_set_elements/4, 
	 table_set_status/7, 
	 
	]).

-ifndef(no_old_style_behaviour_def).
-export([behaviour_info/1]).
-endif.

%% gen_server callbacks
-export([init/1, 
	 handle_call/3, handle_cast/2, handle_info/2, 
	 terminate/2,
         code_change/3]).

-export_type([
	      name/0, 
	      module/0, 
              priority/0, 
	      open_option/0, 
	      open_options/0, 
	      open_option_key/0, 
	      open_option_value/0 
	     ]).

-include("snmpa_internal.hrl").
-include("snmp_debug.hrl").
-include("snmp_verbosity.hrl").

%% -define(VMODULE, "LDB").
-include("snmp_verbosity.hrl").

-define(MK_TABLE_NAME(Pre, Post), 
	list_to_atom(atom_to_list(Pre) ++ "_" ++ atom_to_list(Post))).
-define(MK_CACHE_NAME(Name),  ?MK_TABLE_NAME(Name, cache)).


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


-type name()              :: atom(). % Name of the local-db
-type module()            :: atom(). % Module implementing this behaviour

-type priority()          :: proc_lib:priority_level().
-type open_options()      :: [open_option()].
-type open_option()       :: {open_option_key(), open_option_value()}.
-type open_option_key()   :: atom().
-type open_option_value() :: term().


%%%-------------------------------------------------------------------
%%% Local DB behaviour definition
%%%-------------------------------------------------------------------

-callback open(Options :: open_options()) ->
    {ok, State :: term()} | {error, Reason :: term()}.

-callback handle_close(State :: term()) ->
    snmp:void().

-callback handle_insert(State :: term(), 
			Key   :: term(), 
			Val   :: term()) ->
    {ok, NewState :: term()} | {error, Reason :: term()}.

-callback handle_delete(State :: term(), Key :: term()) ->
    {ok, NewState :: term()} | {error, Reason :: term()}.

-callback handle_lookup(State :: term(), Key :: term()) ->
    {value, Value :: term()} | false.

-callback handle_match(State   :: term(), 
		       Pattern :: ets:match_pattern()) ->
    [Match :: [term()]].



%%%-------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------

-spec start_link(Name   :: name(), 
		 Module :: module(), 
		 Opts   :: list()) ->
    {ok, Pid :: pid()} | {error, Reason :: term()}.
    
start_link(Name, Module, Opts) -> 
    ?d("start_link -> entry with"
       "~n   Name:   ~p"
       "~n   Module: ~p"
       "~n   Opts:   ~p", [Name, Module, Opts]),
    ?GS_START_LINK(Name, Module, Opts).


-spec stop(Name :: name()) ->
    snmp:void(). 

stop(Name) ->
    call(Name, stop).


-spec verbosity(Name :: name(), NewVerbosity :: snmp_verbosity:verbosity()) ->
    OldVerbosity :: snmp_verbosity:verbosity().

verbosity(Name, V) ->
    call(Name, {verbosity, V}).


-spec variable_get(Name     :: name(), 
		   Variable :: term()) ->
    {value, Value :: term()} | undefined.

variable_get(Name, Variable) ->
    call(Name, {variable_get, Variable}).

-spec variable_set(Name     :: name(), 
		   Variable :: term(), 
		   Value    :: term()) ->
    boolean().

variable_set(Name, Variable, Value) ->
    call(Name, {variable_set, Variable, Value}).

-spec variable_inc(Name     :: name(), 
		   Variable :: term()) ->
    snmp:void().

variable_inc(Name, Variable) ->
    variable_inc(Name, Variable, 1).

-spec variable_inc(Name     :: name(), 
		   Variable :: term(), 
		   N        :: pos_integer()) ->
    snmp:void().

variable_inc(Name, Variable, N) 
  when is_integer(N) andalso (N > 0) andalso (N < 4294967296) ->
    cast(Name, {variable_inc, Variable, N}).

-spec variable_delete(Name     :: name(), 
		      Variable :: term()) ->
    snmp:void().

variable_delete(Name, Variable) ->
    call(Name, {variable_delete, Variable}).


-spec table_create(Name  :: name(), 
		   Table :: term()) ->
    boolean().

table_create(Name, Table) ->
    call(Name, {table_create, Table}).

-spec table_exists(Name  :: name(), 
		   Table :: term()) ->
    boolean().

table_exists(Name, Table) ->
    call(Name, {table_exists, Table}).

-spec table_delete(Name  :: name(), 
		   Table :: term()) ->
    snmp:void().

table_delete(Name, Table) ->
    call(Name, {table_delete, Table}).


-spec table_get(Name  :: name(), 
		Table :: term()) ->
    [{Index :: snmp:oid(), Row :: tuple()}].

table_get(Name, Table) ->
    table_get(Name, Table, [], []).

table_get(Name, Table, Idx, Acc) ->
    case table_next(Name, Table, Idx) of
        endOfTable ->
            lists:reverse(Acc);
        NextIdx ->
            case table_get_row(Name, Table, NextIdx) of
                undefined ->
                    {error, {failed_get_row, NextIdx, lists:reverse(Acc)}};
                Row ->
                    table_get(Name, Table, NextIdx, [{NextIdx, Row}|Acc])
            end
    end.

-spec table_next(Name    :: name(), 
		 Table   :: term(), 
		 RestOid :: snmp:oid()) ->
    Row :: tuple() | endOfTable.

table_next(Name, Table, RestOid) ->
    call(Name, {table_next, Table, RestOid}).


-spec table_delete_row(Name     :: name(), 
		       Table    :: term(), 
		       RowIndex :: snmp:oid()) ->
    boolean().

table_delete_row(Name, Table, RowIndex) ->
    call(Name, {table_delete_row, Table, RowIndex});

-spec table_get_row(Name     :: name(), 
		    Table    :: term(), 
		    RowIndex :: snmp:oid(), 
		    FOI      :: non_neg_integer()) ->
    undefined | Row :: tuple().

table_get_row(Name, Table, RowIndex, _FOI) ->
    call(Name, {table_get_row, Table, RowIndex}).

-spec table_create_row(Name     :: name(), 
		       Table    :: term(), 
		       RowIndex :: snmp:oid(), 
		       Row      :: tuple()) ->
    boolean().

table_create_row(Name, Table, RowIndex, Row) ->
    call(Name, {table_create_row, Table, RowIndex, Row}).

-spec table_create_row(Name     :: name(), 
		       Table    :: term(), 
		       RowIndex :: snmp:oid(), 
		       Status   :: row_status(), 
		       Cols     :: [{Col :: non_neg_integer(), 
				     Val :: term()}]) ->
    boolean().

table_create_row(Name, Table, RowIndex, Status, Cols) ->
    Row = snmp_generic_lib:table_construct_row(Table, RowIndex, Status, Cols),
    table_create_row(Name, Table, RowIndex, Row).


-spec table_get_element(Name     :: name(), 
			Table    :: term(), 
			RowIndex :: snmp:oid(), 
			Col      :: non_neg_integer()) ->
    undefined | {value, Value :: term()}. 

table_get_element(Name, Table, RowIndex, Col) ->
    call(Name, {table_get_element, Table, RowIndex, Col}).

-spec table_get_elements(Name     :: name(), 
			 Table    :: term(), 
			 RowIndex :: snmp:oid(), 
			 Cols     :: [non_neg_integer()], 
			 FOI      :: non_neg_integer()) ->
    undefined | [{Col :: non_neg_integer(), Val :: term()}].

table_get_elements(Name, Table, RowIndex, Cols, _FOI) ->
    get_elements(Cols, table_get_row(Name, Table, RowIndex)).

get_elements(_Cols, undefined) -> 
    undefined;
get_elements([Col | Cols], Row) when is_tuple(Row) andalso (size(Row) >= Col) ->
    [element(Col, Row) | get_elements(Cols, Row)];
get_elements([], _Row) -> 
    [].


-spec table_set_element(Name     :: name(), 
			Table    :: term(), 
			RowIndex :: snmp:oid(), 
			Col      :: non_neg_integer(), 
			Value    :: term()) ->
    boolean().

table_set_element(Name, Table, RowIndex, Col, Value) ->
    table_set_elements(Name, Table, RowIndex, [{Col, Value}]).

-spec table_set_elements(Name     :: name(), 
			 Table    :: term(), 
			 RowIndex :: snmp:oid(), 
			 Cols     :: [{Col :: non_neg_integer(), 
				       Val :: term()}]) ->
    boolean().

table_set_elements(Name, Table, RowIndex, Cols) ->
    call(Name, {table_set_elements, Table, RowIndex, Cols}).


-spec table_max_col(Name  :: name(), 
		    Table :: term(), 
		    Col   :: pos_integer()) ->
    Max :: non_neg_integer(). 

table_max_col(Name, Table, Col) ->
    call(Name, {table_max_col, Table, Col}).


-spec match(Name    :: name(), 
	    Table   :: term(), 
	    Pattern :: ets:match_pattern()) ->
    [Match :: [term()]].

match(Name, Table, Pattern) ->
    call(Name, {match, Table, Pattern}). 


%%-----------------------------------------------------------------
%% Functions for debugging.
%%-----------------------------------------------------------------

%% Returns the entire database in raw form
%% Intended for debugging
which_db(Name, ) ->
    call(Name, which_cb).

%% Returns the table as a list of rows
which_table(Name, Table) ->
    call(Name, {which_table, Table}).

which_tables(Name) ->
    call(Name, which_tables).

which_variables(Name) ->
    call(Name, which_variables).


%%----------------------------------------------------------------------
%% This should/could be a generic function, but since Mnesia implements
%% its own and this version still is local_db dependent, it's not 
%% generic yet.
%%----------------------------------------------------------------------

-spec table_set_status(Name              :: name(), 
		       Table             :: term(), 
		       RowIndex          :: snmp:oid(), 
		       RowStatus         :: row_status(), 
		       StatusCol         :: non_neg_integer(), 
		       Cols              :: [non_neg_integer()], 
		       ChangedStatusFunc :: function(), 
		       ConsFunc          :: function()) ->
    {noError, 0} | {Error :: atom(), Col :: non_neg_integer()}.

%% *** createAndGo ***

table_set_status(Name, Table, RowIndex, 
		 ?'RowStatus_createAndGo', 
		 StatusCol, Cols, ChangedStatusFunc, _ConsFunc) ->
    case table_create_row(Name, Table, RowIndex, 
			  ?'RowStatus_active', Cols) of
        true -> 
	    snmp_generic:try_apply(ChangedStatusFunc,
				   [Name, Table, 
				    ?'RowStatus_createAndGo',
				    RowIndex, Cols]);
        _ -> 
	    {commitFailed, StatusCol}
    end;


%% *** createAndWait *** 
%% Set status to notReady, and try to make row consistent.

table_set_status(Name, Table, RowIndex, 
		 ?'RowStatus_createAndWait', 
		 StatusCol, Cols, ChangedStatusFunc, ConsFunc) ->
    case table_create_row(Name, Table, RowIndex, 
			  ?'RowStatus_notReady', Cols) of
        true -> 
            case snmp_generic:try_apply(ConsFunc, 
					[Name, Table, RowIndex, Cols]) of
                {noError, 0} ->
                    snmp_generic:try_apply(ChangedStatusFunc, 
                                           [Name, Table, 
					    ?'RowStatus_createAndWait',
                                            RowIndex, Cols]);
                Error -> 
		    Error
            end;
        _ -> 
	    {commitFailed, StatusCol}
    end;


%% *** destroy ***

table_set_status(Name, Table, RowIndex, 
		 ?'RowStatus_destroy', _StatusCol, Cols,
                 ChangedStatusFunc, _ConsFunc) ->
    case snmp_generic:try_apply(ChangedStatusFunc,
                                [Name, Table, 
				 ?'RowStatus_destroy',
                                 RowIndex, Cols]) of
        {noError, 0} ->
            table_delete_row(Name, Table, RowIndex),
            {noError, 0};
        Error -> Error
    end;

%% *** Otherwise (active or notInService) ***
table_set_status(Name, Table, RowIndex, Val, _StatusCol, Cols,
                 ChangedStatusFunc, ConsFunc) ->
    snmp_generic:table_set_cols(Name, Table, RowIndex, Cols, ConsFunc),
    snmp_generic:try_apply(ChangedStatusFunc, 
			   [Name, Table, Val, RowIndex, Cols]).


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
            {stop, {error, Reason}}
    end.


do_init(Name, Module, Opts) ->
    process_flag(priority,  get_prio(Opts)),
    process_flag(trap_exit, true),
    put(sname,     sname(Name)),
    put(verbosity, get_verbosity(Opts)),
    ?vlog("starting",[]),
    open(#state{db_module = Module}, cleanup_opts(Opts)). 


%% Remove any options used here, 
%% so that the db-module only gets its own options
cleanup_opts([]) ->
    [];
cleanup_opts([{priority, _} | Opts]) ->
    cleanup_opts(Opts);
cleanup_opts([{verbosity, _} | Opts]) ->
    cleanup_opts(Opts);
cleanup_opts([Opt | Opts]) ->
    [Opt | cleanup_opts(Opts)].

    
%%-----------------------------------------------------------------
%% Implements the variable functions.
%%-----------------------------------------------------------------
handle_call({verbosity,Verbosity}, _From, State) ->
    ?vlog("verbosity: ~p -> ~p",[get(verbosity), Verbosity]),
    OldVerbosity = 
	case get(verbosity) of
	    undefined ->
		silence;
	    V ->
		V
	end, 
    put(verbosity, ?vvalidate(Verbosity)),
    {reply, OldVerbosity, State};

handle_call({variable_get, Variable}, _From, State) -> 
    ?vlog("variable get: ~p", [Variable]),
    Reply = lookup(State, Variable), 
    {reply, Reply, NewState};

handle_call({variable_set, Variable, Val}, _From, State) -> 
    ?vlog("variable ~p set: "
	  "~n   Val:  ~p", [Variable, Val]),
    {Reply, NewState} = insert(State, Variable, Val), 
    {reply, Reply, NewState};

handle_call({variable_delete, Variable}, _From, State) -> 
    ?vlog("variable delete: ~p", [Variable]),
    {Reply, NewState} = delete(State, Variable), 
    {reply, Reply, NewState};


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
    Res = table_max_col(Name, Table, Col, 0, first, State),
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
    NewVal = (M+N) rem 4294967296, 
    {_Reply, NewState} = insert(State, Variable, NewVal), 
    {noreply, NewState};
    
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
%% DB backend interface/wrapper functions
%%------------------------------------------------------------------

open(#state{db_module = DBModule} = State, Opts) ->
    try DBModule:open(Opts) of
	{ok, DBState} ->
	    {ok, State#state{db_state = DBState}}
    catch
	T:E ->
	    error_msg("Open failed (~w): "
		      "~n   ~p", [T, E]),
	    {error, {T, E}}
    end.


close(#state{db_module = Module, 
	     db_state  = DBState} = State) ->
    try DBModule:handle_close(DBState) of
	ok ->
	    State#state{db_state = undefined}
    catch
	T:E ->
	    error_msg("Close failed (~w): "
		      "~n   ~p", [T, E]),
	    State
    end.


insert(#state{db_module = DBModule, 
	      db_state  = DBState} = State, Key, Value) ->
    try DBModule:handle_insert(DBState, Key, Value) of
	{ok, NewDBState} ->
	    {true, State#state{db_state = NewDBState}};
	{error, Reason} ->
	    error_msg("Insert failed (~w) for ~p with value ~p: "
		      "~n   ~p", [T, Key, Value, Reason]),
	    {false, State}
    catch
	T:E ->
	    error_msg("Insert failed (~w) for ~p with value ~p: "
		      "~n   ~p", [T, Key, Value, E]),
	    {false, State}	    
    end.


delete(#state{db_module = DBModule, 
	      db_state  = DBState} = State, Key) ->
    try DBModule:handle_delete(DBState, Key) of
	{ok, NewDBState} ->
	    {true, State#state{db_state = NewDBState}};
	{error, Reason} ->
	    error_msg("Delete failed for ~p: "
		      "~n   ~p", [Key, Reason]),
	    {false, State}
    catch
	T:E ->
	    error_msg("Delete failed (~w) for ~p: "
		      "~n   ~p", [T, Key, E]),
	    {false, State}
    end.


lookup(#state{db_module = DBModule, 
	      db_state  = DBState} = _State, Key) ->
    try DBModule:handle_lookup(DBState, Key) of
	false ->
	    false;
	{value, _} = Value ->
	    Value
    catch
	T:E ->
	    error_msg("Lookup failed (~w) for ~p: "
		      "~n   ~p", [T, Key, E]),
	    false
    end.


match(#state{db_module = Module, 
	     db_state  = DBState} = State, Pattern) ->
    try DBModule:handle_match(DBState, Pattern) of
	Match when is_list(Match) ->
	    Match
    catch
	T:E ->
	    error_msg("Match failed (~w) for ~p: "
		      "~n   ~p", [T, Pattern, E]),
	    []
    end.





%%-----------------------------------------------------------------
%% Implementation of max.
%% The value in a column could be noinit or undefined,
%% so we must check only those with an integer.
%%-----------------------------------------------------------------
table_max_col(Name, Table, Col, Max, RowIndex, State) ->
    case lookup(State, {Table, RowIndex}) of
        {value, {Row, _Prev, Next}} when (Next =:= first) -> 
	    Val = element(Col, Row), 
	    if 
		is_integer(Val) andalso (Val > Max) -> 
		    Val;
		true ->
		    Max
	    end;
        {value, {Row, _Prev, Next}} -> 
	    Val = element(Col, Row), 
	    if 
                is_integer(Val) andalso (Val > Max) -> 
                    table_max_col(Name, Table, Col, Val, Next, State);
                true -> 
                    table_max_col(Name, Table, Col, Max, Next, State)
            end;
        undefined -> 
	    Max
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
