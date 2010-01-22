%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2010. All Rights Reserved.
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
%%

-module(httpc_simple).

-include("httpc_internal.hrl").
-include("http_internal.hrl").


%%--------------------------------------------------------------------
%% Internal Application API
-export([
	 request/2
	]).


-record(state, 
	{
	 socket, 
	 socket_type, 
	 options, 
	 mfa, 
	 status_line, 
	 headers, 
	 body
	}
       ).

-define(MAX_HEADER_SIZE, nolimit).
-define(MAX_BODY_SIZE,   nolimit).


%%====================================================================
%% External functions
%%====================================================================

request(Request, Options) ->
    Self    = self(),
    Worker  = spawn_link(fun() -> do_request(Self, Request, Options) end),
    receive
	{Worker, Result} ->
	    Result;
	{'EXIT', Worker, Reason} ->
	    NewReason = {worker_crashed, Reason},
	    {error, NewReason}
    end.
    
    

%%====================================================================
%% Internal functions
%%====================================================================

do_request(Parent, 
	   #request{address = Address0, scheme  = Scheme} = Request0, 
	   #simple_options{proxy = Proxy} = Options) ->
    ?hcrv("do request", 
	  [{address0, Address0}, {sheme, Scheme}, {proxy, Proxy}]),
    try
	begin
	    State1  = #state{options = Options}, 
	    Request = handle_request(Request0), 
	    Address = handle_proxy(Address0, Proxy, Scheme),
	    State2  = connect(Address, Request, State1),
	    State3  = send(Address, Request, State2),
	    Result  = await_response(Request, State3),
	    Parent ! {self(), Result},
	    close(State3)
	end
    catch
	throw:Error ->
	    Parent ! {self(), Error}
    end,
    exit(normal).

handle_request(
  #request{settings = #http_options{version = "HTTP/0.9"}} = Request0) ->
    Request1 = update_request_id(Request0),
    Hdrs0    = Request1#request.headers, 
    Hdrs1    = Hdrs0#http_request_h{connection = undefined},
    Request2 = Request1#request{headers = Hdrs1}, 
    Request2;

handle_request(
  #request{settings = #http_options{version = "HTTP/1.0"}} = Request0) ->
    Request1 = update_request_id(Request0),
    Hdrs0    = Request1#request.headers, 
    Hdrs1    = Hdrs0#http_request_h{connection = "close"},
    Request2 = Request1#request{headers = Hdrs1}, 
    Request2;
handle_request(Request0) ->
    Request1 = update_request_id(Request0),
    Hdrs0    = Request1#request.headers, 
    Hdrs1    = Hdrs0#http_request_h{connection = "close"},
    Request2 = Request1#request{headers = Hdrs1}, 
    Request2.
    
update_request_id(Request) ->
    Request#request{id = make_ref()}.



%% -------- Proxy stuff ----------

handle_proxy(Address0, Proxy, https = _Scheme) ->
    Address = handle_proxy(Address0, Proxy),
    if
	(Address =/= Address0) ->
	    Reason = https_through_proxy_is_not_supported,
	    Error  = {error, Reason},
	    throw(Error);
	true ->
	    Address
    end;
handle_proxy(Address, _Proxy, _Scheme) ->
    Address.


%%% Check to see if the given {Host,Port} tuple is in the NoProxyList
%%% Returns an eventually updated {Host,Port} tuple, with the proxy address
handle_proxy(HostPort = {Host, _Port}, {Proxy, NoProxy}) ->
    case Proxy of
	undefined ->
	    HostPort;
	Proxy ->
	    case is_no_proxy_dest(Host, NoProxy) of
		true ->
		    HostPort;
		false ->
		    Proxy
	    end
    end.

is_no_proxy_dest(_, []) ->
    false;
is_no_proxy_dest(Host, [ "*." ++ NoProxyDomain | NoProxyDests]) ->    
    
    case is_no_proxy_dest_domain(Host, NoProxyDomain) of
	true ->
	    true;
	false ->
	    is_no_proxy_dest(Host, NoProxyDests)
    end;

is_no_proxy_dest(Host, [NoProxyDest | NoProxyDests]) ->
    IsNoProxyDest = 
	case http_util:is_hostname(NoProxyDest) of
	    true ->
		fun(H, NP) -> is_no_proxy_host_name(H, NP) end;
	    false ->
		fun(H, NP) -> is_no_proxy_dest_address(H, NP) end
	end,
    
    case IsNoProxyDest(Host, NoProxyDest) of
	true ->
	    true;
	false ->
	    is_no_proxy_dest(Host, NoProxyDests)
    end.

is_no_proxy_host_name(Host, Host) ->
    true;
is_no_proxy_host_name(_,_) ->
    false.

is_no_proxy_dest_domain(Dest, DomainPart) ->
    lists:suffix(DomainPart, Dest).

is_no_proxy_dest_address(Dest, Dest) ->
    true;
is_no_proxy_dest_address(Dest, AddressPart) ->
    lists:prefix(AddressPart, Dest).


%% -------- Connect stuff ----------

connect(Address, 
	#request{settings    = Settings,
		 socket_opts = SockOpts} = Request, 
       #state{options = Options} = State) ->
    SocketType  = socket_type(Request),
    ConnTimeout = Settings#http_options.connect_timeout,
    Socket      = connect(SocketType, Address, SockOpts, Options, ConnTimeout),
    State#state{socket = Socket, socket_type = SocketType}.

connect(SocketType, Address, SockOpts, Options, ConnTimeout) ->
    case do_connect(SocketType, Address, SockOpts, Options, ConnTimeout) of
	{ok, Socket} ->
	    Socket;
	{error, Reason} ->
	    NewReason = {connect_failed, Reason},
	    throw({error, NewReason})
    end.

do_connect(SocketType, ToAddress, SockOpts, 
	   #simple_options{ipfamily    = IpFamily,
			   ip          = FromAddress,
			   port        = FromPort}, Timeout) ->
    Opts1 = 
	case FromPort of
	    default ->
		SockOpts;
	    _ ->
		[{port, FromPort} | SockOpts]
	end,
    Opts2 = 
	case FromAddress of
	    default ->
		Opts1;
	    _ ->
		[{ip, FromAddress} | Opts1]
	end,
    case IpFamily of
	inet6fb4 ->
	    Opts3 = [inet6 | Opts2],
	    case http_transport:connect(SocketType, ToAddress, Opts3, Timeout) of
		{error, Reason} when ((Reason =:= nxdomain) orelse 
				      (Reason =:= eafnosupport)) -> 
		    Opts4 = [inet | Opts2], 
		    http_transport:connect(SocketType, ToAddress, Opts4, Timeout);
		Other ->
		    Other
	    end;
	_ ->
	    Opts3 = [IpFamily | Opts2], 
	    http_transport:connect(SocketType, ToAddress, Opts3, Timeout)
    end.
		

%% -------- Send stuff ----------

send(Address, Request, 
     #state{socket = Socket, socket_type = SocketType} = State) ->
    case httpc_request:send(Address, Request, Socket) of
	ok ->
	    activate_once(SocketType, Socket),
	    maybe_activate_request_timeout(Request);
	{error, Reason} ->
	    NewReason = {send_failed, Reason},
	    throw({error, NewReason})
    end.

maybe_activate_request_timeout(#request{settings = Settings}) ->
    case Settings#http_options.timeout of
	infinity ->
	    ignore;
	Timeout ->
	    ReqId = Request#request.id,
	    Msg   = {simple_timeout, ReqId},
	    erlang:send_after(Timeout, self(), Msg)
    end.
	    
    
%% -------- Await Response stuff ----------

await_response(Timer, Socket, Request) ->
    State = init_state(Timer, Socket, Request),
    await_response(Request, State).

init_state(Timer, Socket, #request{sheme = Scheme, settings = Settings}) ->
    SocketType = socket_type(Scheme), 
    case Settings#http_options.version of
        "HTTP/0.9" ->
	    MFA        = {httpc_response, whole_body, [<<>>, -1]},
	    StatusLine = {"HTTP/0.9", 200, "OK"},
	    #status{socket      = Socket, 
		    socket_type = SocketType, 
		    timer       = Timer, 
		    mfa         = MFA,
		    status_line = StatusLine};
        _ ->
            Relaxed    = Settings#http_options.relaxed,
            MFA        = {httpc_response, parse, [?MAX_HEADER_SIZE, Relaxed]},
	    StatusLine = undefined,
	    #status{socket      = Socket, 
		    socket_type = SocketType, 
		    timer       = Timer, 
		    mfa         = MFA,
		    status_line = StatusLine}
    end.
	    

await_response(Request, State) ->
    receive
	{Proto, Socket, Data} when (((Proto =:= tcp) orelse (Proto =:= ssl)) 
				     andalso 
				    (Socket =:= State#state.socket)) ->
	   case handle_data(Data, State) of
	       {continue, NewState} ->
		   activate_once(State),
		   await_response(Timer, Socket, Request, NewState);
	       {reply, Result} ->
		   Result
	   end;

	{tcp_closed, _} ->
	    case State#state.mfa of
		{_, whole_body, Args} ->
		    handle_response(State#state{body = hd(Args)});
		_ ->
		    Reason = {remote_close, State#state.body},
		    {error, Reason}
	    end;

	{ssl_closed, _} ->
	    case State#state.mfa of
		{_, whole_body, Args} ->
		    handle_response(State#state{body = hd(Args)});
		_ ->
		    Reason = {remote_close, State#state.body},
		    {error, Reason}
	    end;

	{tcp_error, _, _} = Reason ->
	    {error, {Reason, State#state.body}};
	
	{ssl_error, _, _} = Reason ->
	    {error, {Reason, State#state.body}};
	
	{simple_timeout, ReqId} when Request#request.id =:= ReqId ->
	    Reason = {timeout, State#state.body},
	    {error, Reason}

    end.


handle_data(Data, 
	    #request{method = Method} = Request, 
	    #state{mfa         = {Module, Function, Args},
		   status_line = StatusLine} = State) ->

    ?hcri("handle received data", [{module,      Module},
				   {function,    Function},
				   {method,      Method},
				   {status_line, StatusLine}]),

    try Module:Function([Data | Args]) of
	{ok, Result} ->
	    ?hcrd("data processed - ok", []),
	    handle_http_msg(Result, State);
	
	{_, whole_body, _} when Method =:= head ->
	    ?hcrd("data processed - whole body", []),
	    handle_response(State#state{body = <<>>});
	
	{Module, whole_body, [Body, Length]} ->
	    ?hcrd("data processed - whole body", [{length, Length}]),
	    NewMFA = {Module, whole_body, [Body, Length]},
	    {contibue, State#state{mfa = NewMFA}};
	
	NewMFA ->
	    ?hcrd("data processed - new mfa", []),
	    {continue, State#state{mfa = NewMFA}}
    
    catch
	exit:_Exit ->
	    ?hcrd("data processing exit", [{exit, _Exit}]),
	    Reason = {parse_failed, Data},
	    Error  = {error, Reason}, 
	    {reply, Error};
	error:_Error ->
	    ?hcrd("data processing error", [{error, _Error}]),
	    Reason = {parse_failed, Data},
	    Error  = {error, Reason}, 
	    {reply, Error}
    
    end.
	


%%====================================================================
%% Misc utility functions
%%====================================================================

activate_once(#state{socket = Socket, socket_type = SocketType}) ->
    http_transport:setopts(SocketType, Socket, [{active, once}]).

close(#state{socket = Socket, socket_type = SocketType}) ->
    close(SocketType, Socket).

close(SocketType, Socket) ->
    http_transport:close(SocketType, Socket).
    

socket_type(#request{scheme = http}) ->
    ip_comm;
socket_type(#request{scheme = https, settings = Settings}) ->
    {ssl, Settings#http_options.ssl};
socket_type(http) ->
    ip_comm;
socket_type(https) ->
    {ssl, []}. %% Dummy value ok for ex setopts that does not use this value

t() ->
    http_util:timestamp().
