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
-module(snmpa_ldb_persistent).

-behaviour(snmpa_local_db).

-include_lib("kernel/include/file.hrl").
-include("snmpa_internal.hrl").
-include("snmp_types.hrl").
-include("STANDARD-MIB.hrl").

-export([
	 start_link/1,
	 stop/0, 
	 verbosity/1,
	 variable_get/1, 
	 variable_set/2, 
	 /2,
	 /1
	]).

%% snmpa_ldb callback functions
-export([
	 init/1,
	 insert/3, 
	 delete/2,
	 match/3, 
	 lookup/2,
	 close/1
	]).

-define(NAME, ?MODULE).
-define(TAB,  ?MODULE).

start_link(Opts) ->
    snmpa_ldb:start_link(?NAME, ?MODULE, [{sname, pers_ldb}|Opts]).
    
stop() ->
    snmpa_ldb:stop(?NAME).

verbosity(Verbosity) ->
    snmpa_ldb:verbosity(?NAME, Verbosity).

variable_get(Variable) ->
    snmpa_ldb:variable_get(?NAME, Variable).

variable_set(Variable, Value) ->
    snmpa_ldb:variable_set(?NAME, Variable, Value).


%% -------------------------------------------------------------------- 
%% snmpa_ldb callback functions

init(Opts) ->
    FileName = dets_filename(?TAB, get_dir(Opts)),
    case file:read_file_info(FileName) of
	{ok, #file_info{type = regular}} ->
	    %% File exist, try opening it
	    case dets_open(?TAB, FileName, Opts) of
		{ok, Tab} ->
		    ?vdebug("dets open done", []),
		    ShadowTab = ets:new(?SHADOW_TAB, [set, protected]),
		    dets:to_ets(Tab, ShadowTab),
		    ?vtrace("shadow table created and populated",[]),
		    {ok, #state{shadow = ShadowTab, tab = Tab}};
		{error, Reason1} ->
		    user_err("Could not open persistent database: ~p", 
			     [Filename]),
		    case get_init_error(Opts) of
			terminate ->
			    throw({error, {failed_open_dets, Reason1}});
			_ ->
			    Saved = Filename ++ ".saved",
			    file:rename(Filename, Saved),
			    case do_dets_open(Name, Filename, Opts) of
				{ok, Tab} ->
				    ShadowTab = 
					ets:new(?SHADOW_TAB, [set, protected]),
				    #status{tab = Tab, shadow = ShadowTab};
				{error, Reason2} ->
				    user_err("Could not create persistent "
					     "database: ~p"
					     "~n   ~p"
					     "~n   ~p", 
					     [Filename, Reason1, Reason2]),
				    throw({error, {failed_open_dets, Reason2}})
			    end
		    end
	    end;
	_ ->
	    case do_dets_open(?TAB, Filename, Opts) of
		{ok, Tab} ->
		    ?vdebug("dets create done",[]),
		    ShadowTab = ets:new(?SHADOW_TAB, [set, protected]),
		    ?vtrace("shadow table created",[]),
		    #status{tab = Tab, shadow = ShadowTab};
		{error, Reason} ->
		    user_err("Could not create persistent database ~p"
			     "~n   ~p", [Filename, Reason]),
		    throw({error, {failed_open_dets, Reason}})
	    end
    end.

insert(#state{tab = Tab, shadow_tab = ShadowTab}, Key, Value) ->
    Data = {Key, Value}, 
    ets:insert(ShadowTab, Data),
    dets:insert(Tab, Data), 
    true.

delete(#state{tab = Tab, shadow_tab = ShadowTab}, Key) ->
    ets:delete(ShadowTab, Key),
    dets:delete(Tab, Key), 
    true.

match(#state{shadow_tab = ShadowTab}, Pattern) ->
    ets:match(ShadowTab, {{Name,'_'}, {Pattern,'_','_'}}).

lookup(#state{tab = Tab}, Key) ->
    case ets:lookup(Tab, Key) of
	[{_, Value}] ->
	    {value, Value};
	[] ->
	    undefined
    end.

close(#state{tab = Tab}) ->
    ets:delete(Tb).


%% -------------------------------------------------------------------- 

do_dets_open(Name, Filename, Opts) ->
    Repair   = get_opt(repair, Opts, true),
    AutoSave = get_opt(auto_save, Opts, 5000),
    Args = [{auto_save, AutoSave},
	    {file,      Filename},
	    {repair,    Repair}],
    dets:open_file(Name, Args).

    
dets_filename(Name, Dir) when is_atom(Name) ->
    dets_filename(atom_to_list(Name), Dir);
dets_filename(Name, Dir) ->
    filename:join(dets_filename1(Dir), Name).
    
dets_filename1([])  -> ".";
dets_filename1(Dir) -> Dir.


