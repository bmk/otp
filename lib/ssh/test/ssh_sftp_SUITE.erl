%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2005-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

%%
-module(ssh_sftp_SUITE).

-export([
         suite/0,
         all/0,
         groups/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_group/2,
         end_per_group/2,
         init_per_testcase/2,
         end_per_testcase/2
        ]).

-export([
         ascii_filename_ascii_contents_to_tar/1,
         ascii_filename_unicode_contents_to_tar/1,
         async_read/1,
         async_write/1,
         big_file_to_tar/1,
         binaries_to_tar/1,
         block_size_16_crypto_tar/1,
         block_size_1_crypto_tar/1,
         create_empty_tar/1,
         directory_to_tar/1,
         file_owner_access/1,
         files_chunked_to_tar/1,
         files_to_tar/1,
         links/1,
         mk_rm_dir/1,
         null_crypto_tar/1,
         open_close_dir/1,
         open_close_file/1,
         pos_read/1,
         pos_write/1,
         position/1,
         read_6GB/1,
         read_crypto_tar/1,
         read_dir/1,
         read_file/1,
         read_null_crypto_tar/1,
         read_tar/1,
         remove_file/1,
         rename_file/1,
         retrieve_attributes/1,
         set_attributes/1,
         sftp_nonexistent_subsystem/1,
         sftp_read_big_file/1,
         simple_crypto_tar_big/1,
         simple_crypto_tar_small/1,
         start_channel_sock/1,
         stuff/1,
         unicode_filename_ascii_contents_to_tar/1,
         unstuff/1,
         version_option/1,
         write_big_file/1,
         write_file/1,
         write_file_iolist/1
        ]).

-include_lib("common_test/include/ct.hrl").
-include_lib("kernel/include/file.hrl").
-include("ssh_test_lib.hrl").
-include_lib("stdlib/include/assert.hrl").

%% Default timetrap timeout
-define(default_timeout, test_server:minutes(0.5)).

%%--------------------------------------------------------------------
%% Common Test interface functions -----------------------------------
%%--------------------------------------------------------------------

suite() ->
    [{ct_hooks,[ts_install_cth]},
     {timetrap,{seconds,20}}].

all() -> 
    [{group, not_unicode},
     {group, unicode}
    ].


init_per_suite(Config) ->
    ?CHECK_CRYPTO(
       begin
	   ct:log("file:native_name_encoding() = ~p,~nio:getopts() = ~p",
		  [file:native_name_encoding(),io:getopts()]),
	   ssh:start(),
	   Config
       end).

end_per_suite(_onfig) ->
    ssh:stop().

%%--------------------------------------------------------------------
groups() -> 
    [{not_unicode, [], [{group,erlang_server},
			{group,openssh_server},
			{group,big_recvpkt_size},
			sftp_nonexistent_subsystem]},

     {unicode, [], [{group,erlang_server},
		    {group,openssh_server},
                    read_6GB,
		    sftp_nonexistent_subsystem
                   ]},

     {big_recvpkt_size, [], [{group,erlang_server},
			     {group,openssh_server}]},

     {erlang_server, [], [{group,write_read_tests},
			  version_option,
			  {group,remote_tar}]},

     {openssh_server, [], [{group,write_read_tests},
			   {group,remote_tar}]},

     {remote_tar, [], [create_empty_tar, 
		       ascii_filename_ascii_contents_to_tar,
		       ascii_filename_unicode_contents_to_tar,
		       unicode_filename_ascii_contents_to_tar,
		       files_to_tar,
		       big_file_to_tar, files_chunked_to_tar,
		       directory_to_tar, binaries_to_tar, null_crypto_tar, 
		       simple_crypto_tar_small, simple_crypto_tar_big,
		       read_tar, read_null_crypto_tar, read_crypto_tar, 
		       block_size_1_crypto_tar, block_size_16_crypto_tar
		      ]},

     {write_read_tests, [], [open_close_file, open_close_dir, read_file, read_dir,
			     write_file, write_file_iolist, write_big_file, sftp_read_big_file,
			     rename_file, mk_rm_dir, remove_file, links,
			     retrieve_attributes, set_attributes, file_owner_access, async_read,
			     async_write, position, pos_read, pos_write,
			     start_channel_sock
			    ]}
    ].

init_per_group(not_unicode, Config) ->
    ct:comment("Begin ~p",[grps(Config)]),
    {ok,TestDataDir} =
        make_data_sub_dir(Config, "test_data", "test_data_not_unicode"),
    [{user, "Alladin"},
     {passwd, "Sesame"},
     {data, <<"Hello world!">>},
     {data_pos, ["Hej ","hopp"]},
     {filename,     "sftp.txt"},
     {testfile,     "test.txt"},
     {linktest,     "link_test.txt"},
     {tar_filename, "sftp_tar_test.tar"},
     {tar_F1_txt,   "f1.txt"},
     {datadir_tar, TestDataDir}
     | Config];

init_per_group(unicode, Config) ->
    case have_unicode_support() of
	true ->
	    ct:comment("Begin ~p",[grps(Config)]),
            {ok,TestDataDir} =
                make_data_sub_dir(Config, "test_data", "test_data_高兴_unicöde"),
            populate_non_unicode(TestDataDir),
	    NewConfig =
		[{user, "åke高兴"},
		 {passwd, "ärlig日本じん"},
                 {data, "foobar å 一二三四いちにさんち"},
                 {data_pos, ["中","国"]},
		 {filename,     "sftp瑞点.txt"},
		 {testfile,     "testハンス.txt"},
		 {linktest,     "link_test語.txt"},
		 {tar_filename, "sftp_tar_test一二三.tar"},
		 {tar_F1_txt,   "F一.txt"},
		 {tar_F3_txt,   "f3.txt"},
		 {tar_F4_txt,   "g四.txt"},
		 {datadir_tar, TestDataDir}
		 | Config %% lists:foldl(fun(K,Cf) -> lists:keydelete(K,1,Cf) end,
			  %%      Config,
			  %%      [user, passwd, data,
			  %%       filename, testfile, linktest,
			  %%       tar_filename, tar_F1_txt, datadir_tar
			  %%      ]
                          %%     )
		],
	    FN = fn(proplists:get_value(tar_F1_txt,NewConfig), NewConfig),
	    case catch file:read_file(FN) of
		{ok,FN_contents} ->
		    ct:log("Readable file:read_file(~tp) ->~n~tp",[FN,FN_contents]),
		    NewConfig;
		Other ->
		    ct:log("Unreadable file:read_file(~tp) ->~n~p",[FN,Other]),
		    {skip, "Not unicode file reading"}
	    end;

	_ ->
	    {skip, "Not unicode file encoding"}
    end;

init_per_group(big_recvpkt_size, Config) ->
    [{pkt_sz,123456} | Config];

init_per_group(erlang_server, Config) ->
    ct:comment("Begin ~p",[grps(Config)]),
    PrivDir = proplists:get_value(priv_dir, Config),
    SysDir =  proplists:get_value(data_dir, Config),
    User = proplists:get_value(user, Config),
    Passwd = proplists:get_value(passwd, Config),
    Sftpd = {_, HostX, PortX} =
	ssh_test_lib:daemon([{system_dir, SysDir},
			     {user_dir, PrivDir},
			     {user_passwords,
			      [{User, Passwd}]}]),
    [{peer, {fmt_host(HostX),PortX}}, {group, erlang_server}, {sftpd, Sftpd} | Config];

init_per_group(openssh_server, Config) ->
    verify_openssh(Config);

init_per_group(remote_tar, Config) ->
    ct:comment("Begin ~p",[grps(Config)]),
    {Host,Port} =  proplists:get_value(peer, Config),
    ct:log("Server (~p) at ~p:~p",[proplists:get_value(group,Config),Host,Port]),
    User = proplists:get_value(user, Config),
    Passwd = proplists:get_value(passwd, Config),
    Connection =
	case proplists:get_value(group, Config) of
	    erlang_server ->
		ssh_test_lib:connect(Host, Port,
			    [{user, User},
			     {password, Passwd},
			     {user_interaction, false},
			     {silently_accept_hosts, true}]);
	    openssh_server ->
		ssh_test_lib:connect(Host, Port,
			    [{user_interaction, false},
			     {silently_accept_hosts, true}])
	end,
    [{remote_tar, true}, 
     {connection, Connection} | Config];

init_per_group(write_read_tests, Config) ->
    ct:comment("Begin ~p",[grps(Config)]),
    Config.

grps(Config) ->
    proplists:get_all_values(
      name, 
      lists:flatten([proplists:get_value(tc_group_properties,Config,[]),
		     proplists:get_value(tc_group_path,Config,[])])).

end_per_group(erlang_server, Config) ->
    ct:comment("End ~p",[grps(Config)]),
    Config;
end_per_group(_, Config) ->
    ct:comment("End ~p",[grps(Config)]),
    Config.

%%--------------------------------------------------------------------
init_per_testcase(read_6GB, Config) ->
    case verify_openssh(Config) of
        Result = {skip, _} ->
            Result;
        _ ->
            case {os:type(), erlang:system_info(system_architecture)} of
                {{win32, _}, _} ->
                    {skip, "/dev/zero not available on Windows"};
                {_, "aarch64"} ->
                    {skip, "machine too slow for test"};
                _ ->
                    init_per_testcase(read_6GB_prepare_openssh_server, Config)
            end
    end;
init_per_testcase(sftp_nonexistent_subsystem, Config) ->
    PrivDir = proplists:get_value(priv_dir, Config),
    SysDir =  proplists:get_value(data_dir, Config),
    User = proplists:get_value(user, Config),
    Passwd = proplists:get_value(passwd, Config),
    Sftpd = ssh_test_lib:daemon([{system_dir, SysDir},
				 {user_dir, PrivDir},
				 {subsystems, []},
				 {user_passwords,
				  [{User, Passwd}]}
				]),
    [{sftpd, Sftpd} | Config];
init_per_testcase(version_option, Config0) ->
    Config = prepare(Config0),
    TmpConfig0 = lists:keydelete(watchdog, 1, Config),
    TmpConfig = lists:keydelete(sftp, 1, TmpConfig0),
    Dog = ct:timetrap(?default_timeout),
    {_,Host, Port} =  proplists:get_value(sftpd, Config),
    User = proplists:get_value(user, Config),
    Passwd = proplists:get_value(passwd, Config),
    {ok, ChannelPid, Connection}  = 
	ssh_sftp:start_channel(Host, Port,
			       [{sftp_vsn, 3},
				{user, User},
				{password, Passwd},
				{user_interaction, false},
				{silently_accept_hosts, true},
                                {save_accepted_host, false}
                               ]),
    Sftp = {ChannelPid, Connection},
    [{sftp,Sftp}, {watchdog, Dog} | TmpConfig];
init_per_testcase(Case, Config00) ->
    Config0 = prepare(Config00),
    Config1 = lists:keydelete(watchdog, 1, Config0),
    Config2 = lists:keydelete(sftp, 1, Config1),
    Dog = ct:timetrap(2 * ?default_timeout),
    User = proplists:get_value(user, Config0),
    Passwd = proplists:get_value(passwd, Config0),
    PktSzOpt = case proplists:get_value(pkt_sz, Config0) of
		   undefined -> [];
		   Sz -> [{packet_size,Sz}]
	       end,
    PrepareOpenSSHServer =
        fun() ->
                Host = ssh_test_lib:hostname(),
        	{ok, ChannelPid, Connection} =
        	    ssh_sftp:start_channel(Host,
        				   [{user_interaction, false},
        				    {silently_accept_hosts, true},
                                            {save_accepted_host, false}
                                           | PktSzOpt
        				   ]),
        	Sftp = {ChannelPid, Connection},
        	[{sftp, Sftp}, {watchdog, Dog} | Config2]
        end,
    Config =
	case proplists:get_value(group,Config2) of
	    erlang_server ->
		{_,Host, Port} = proplists:get_value(sftpd, Config2),
		{ok, ChannelPid, Connection} =
		    ssh_sftp:start_channel(Host, Port,
					   [{user, User},
					    {password, Passwd},
					    {user_interaction, false},
					    {silently_accept_hosts, true},
                                            {save_accepted_host, false}
					    | PktSzOpt
					   ]
					  ),
		Sftp = {ChannelPid, Connection},
		[{sftp, Sftp}, {watchdog, Dog} | Config2];
	    openssh_server when Case == links ->
		{skip, "known bug in openssh"};
	    openssh_server ->
                PrepareOpenSSHServer();
            _ when Case == read_6GB_prepare_openssh_server ->
                PrepareOpenSSHServer()
	end,
    case catch proplists:get_value(remote_tar,Config) of
	%% The 'catch' is for the case of Config={skip,...}
	true ->
	    %% Provide a ChannelPid independent of the sftp-channel already opened.
	    {ok,ChPid2} = ssh_sftp:start_channel(proplists:get_value(connection,Config)),
	    [{channel_pid2,ChPid2} | Config];
	_ ->
	    Config
    end.

end_per_testcase(sftp_nonexistent_subsystem, Config) ->
    Config;
end_per_testcase(rename_file, Config) ->
    NewFileName = proplists:get_value(testfile, Config),
    file:delete(NewFileName),  
    end_per_testcase(Config);
end_per_testcase(_, Config) ->
    end_per_testcase(Config).

end_per_testcase(Config) ->
    {Sftp, Connection} = proplists:get_value(sftp, Config),
    ok = ssh_sftp:stop_channel(Sftp),
    catch ssh_sftp:stop_channel(proplists:get_value(channel_pid2, Config)),
    ok = ssh:close(Connection).

%%--------------------------------------------------------------------
%% Test Cases --------------------------------------------------------
%%--------------------------------------------------------------------
open_close_file(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    ct:log("FileName     = ~p~nSftpFileName = ~p", [FileName, SftpFileName]),
    {Sftp, _} = proplists:get_value(sftp, Config),

    ok = open_close_file(Sftp, SftpFileName, [read]),
    ok = open_close_file(Sftp, SftpFileName, [write]),
    ok = open_close_file(Sftp, SftpFileName, [write, creat]),
    ok = open_close_file(Sftp, SftpFileName, [write, trunc]),
    ok = open_close_file(Sftp, SftpFileName, [append]),
    ok = open_close_file(Sftp, SftpFileName, [read, binary]).

open_close_file(Server, File, Mode) ->
    {ok, Handle} = ssh_sftp:open(Server, File, Mode),
    ok = ssh_sftp:close(Server, Handle).

%%--------------------------------------------------------------------
open_close_dir(Config) when is_list(Config) ->
    PrivDir = proplists:get_value(sftp_priv_dir, Config),
    SftpPrivDir = w2l(Config, PrivDir),
    {Sftp, _} = proplists:get_value(sftp, Config),
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),

    {ok, Handle} = ssh_sftp:opendir(Sftp, SftpPrivDir),
    ok = ssh_sftp:close(Sftp, Handle),
    {error, _} =  ssh_sftp:opendir(Sftp, SftpFileName).

%%--------------------------------------------------------------------
read_file(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),
    {ok, Data} = ssh_sftp:read_file(Sftp, SftpFileName),
    {ok, Data} = ssh_sftp:read_file(Sftp, SftpFileName),
    {ok, Data} = file:read_file(FileName).

%%--------------------------------------------------------------------
read_dir(Config) when is_list(Config) ->
    PrivDir = proplists:get_value(sftp_priv_dir, Config),
    SftpPrivDir = w2l(Config, PrivDir),

    {Sftp, _} = proplists:get_value(sftp, Config),
    {ok, Files} = ssh_sftp:list_dir(Sftp, SftpPrivDir),
    ct:log("sftp list dir: ~p~n", [Files]).

%%--------------------------------------------------------------------
write_file(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),
    Data = proplists:get_value(data, Config),
    Expected = unicode:characters_to_binary(Data),
    ok = ssh_sftp:write_file(Sftp, SftpFileName, [Data]),
    {ok, Expected} = file:read_file(FileName).

%%--------------------------------------------------------------------
write_file_iolist(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),

    Data = proplists:get_value(data, Config),
    DataB = unicode:characters_to_binary(Data),
    lists:foreach(
      fun(D) ->
	      ok = ssh_sftp:write_file(Sftp, SftpFileName, [D]),
	      Expected = try iolist_to_binary(D)
                         catch _:_ -> unicode:characters_to_binary(D)
			 end,
	      {ok, Expected} = file:read_file(FileName)
      end,
      [Data, [Data,Data], [[Data],[Data]], [[[Data]],[[[[Data]],Data]]],
       [[[[Data]],Data],DataB],
       [[[[Data]],Data],[[DataB],[[DataB]]]]
      ]).

%%--------------------------------------------------------------------
write_big_file(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),

    Data = [lists:duplicate(750000,"a"),
            proplists:get_value(data, Config)],
    ok = ssh_sftp:write_file(Sftp, SftpFileName, Data),
    Expected = unicode:characters_to_binary(Data),
    {ok, Expected} = file:read_file(FileName).

%%--------------------------------------------------------------------
sftp_read_big_file(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),

    Data = [lists:duplicate(750000,"a"),
            proplists:get_value(data, Config)],
    ok = ssh_sftp:write_file(Sftp, SftpFileName, Data),
    Expected = unicode:characters_to_binary(Data),
    {ok, Expected} = ssh_sftp:read_file(Sftp, SftpFileName).

%%--------------------------------------------------------------------
remove_file(Config) when is_list(Config) ->
    PrivDir =  proplists:get_value(sftp_priv_dir, Config),
    SftpPrivDir = w2l(Config, PrivDir),
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),

    {ok, Files} = ssh_sftp:list_dir(Sftp, SftpPrivDir),
    true = lists:member(filename:basename(FileName), Files),
    ok = ssh_sftp:delete(Sftp, SftpFileName),
    {ok, NewFiles} = ssh_sftp:list_dir(Sftp, SftpPrivDir),
    false = lists:member(filename:basename(FileName), NewFiles),
    {error, no_such_file} = ssh_sftp:delete(Sftp, SftpFileName).
%%--------------------------------------------------------------------
rename_file(Config) when is_list(Config) ->
    PrivDir =  proplists:get_value(sftp_priv_dir, Config),
    SftpPrivDir = w2l(Config, PrivDir),
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    NewFileName = proplists:get_value(testfile, Config),
    SftpNewFileName = w2l(Config, NewFileName),

    {Sftp, _} = proplists:get_value(sftp, Config),
    {ok, Files} = ssh_sftp:list_dir(Sftp, SftpPrivDir),
    ct:log("FileName: ~p, Files: ~p~n", [FileName, Files]),
    true = lists:member(filename:basename(FileName), Files),
    false = lists:member(filename:basename(NewFileName), Files),
    ok = ssh_sftp:rename(Sftp, SftpFileName, SftpNewFileName),
    {ok, NewFiles} = ssh_sftp:list_dir(Sftp, SftpPrivDir),
    ct:log("FileName: ~p, Files: ~p~n", [FileName, NewFiles]),

    false = lists:member(filename:basename(FileName), NewFiles),
    true = lists:member(filename:basename(NewFileName), NewFiles).

%%--------------------------------------------------------------------
mk_rm_dir(Config) when is_list(Config) ->
    PrivDir = proplists:get_value(sftp_priv_dir, Config),
    SftpPrivDir = w2l(Config, PrivDir),
    {Sftp, _} = proplists:get_value(sftp, Config),

    DirName = filename:join(PrivDir, "test"),
    SftpDirName = w2l(Config, DirName),
    ok = ssh_sftp:make_dir(Sftp, SftpDirName),
    ok = ssh_sftp:del_dir(Sftp, SftpDirName),
    NewDirName = filename:join(PrivDir, "foo/bar"),
    SftpNewDirName = w2l(Config, NewDirName),
    {error, _} = ssh_sftp:make_dir(Sftp, SftpNewDirName),
    {error, _} = ssh_sftp:del_dir(Sftp, SftpPrivDir).

%%--------------------------------------------------------------------
links(Config) when is_list(Config) ->
    case os:type() of
	{win32, _} ->
	    {skip, "Links are not fully supported by windows"};
	_ ->
	    {Sftp, _} = proplists:get_value(sftp, Config),
	    FileName = proplists:get_value(filename, Config),
            SftpFileName = w2l(Config, FileName),
	    LinkFileName = proplists:get_value(linktest, Config),
            SftpLinkFileName = w2l(Config, LinkFileName),

	    ok = ssh_sftp:make_symlink(Sftp, SftpLinkFileName, SftpFileName),
	    {ok, FileName} = ssh_sftp:read_link(Sftp, SftpLinkFileName)
    end.

%%--------------------------------------------------------------------
retrieve_attributes(Config) when is_list(Config) ->
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),
    {ok, SftpFileInfo} = ssh_sftp:read_file_info(Sftp, SftpFileName),
    {ok, FileFileInfo} = file:read_file_info(FileName),
    ct:log("ssh_sftp:read_file_info(): ~p~n"
           "file:read_file_info(): ~p",
           [SftpFileInfo, FileFileInfo]),
    {ExpectedUid, ExpectedGid} =
        case {os:type(), proplists:get_value(group,Config)} of
            {{win32, _}, openssh_server} ->
                %% Windows compiled Erlang is expected will return 0;
                %% but when Erlang(Windows) client interacts with
                %% OpenSSH server - value 1000 is received by client
                %% over SFTP (because OpenSSH is compiled for Linux
                %% and runs on WSL)
                {1000, 1000};
            _ ->
                {FileFileInfo#file_info.uid, FileFileInfo#file_info.gid}
        end,
    ?assertEqual(ExpectedUid, SftpFileInfo#file_info.uid),
    ?assertEqual(ExpectedGid, SftpFileInfo#file_info.gid),
    ok.

%%--------------------------------------------------------------------
set_attributes(Config) when is_list(Config) ->
    FileName = proplists:get_value(testfile, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),
    {ok,Fd} = file:open(FileName, write),
    io:put_chars(Fd,"foo"),
    TestWriting =
        fun(FInfo) ->
                ok = ssh_sftp:write_file_info(Sftp, SftpFileName,
                                              FInfo#file_info{mode=8#400}),
                {error, eacces} = file:write_file(FileName, "hello again"),
                ok = ssh_sftp:write_file_info(Sftp, SftpFileName,
                                              FInfo#file_info{mode=8#600}),
                ok = file:write_file(FileName, "hello again")
        end,
    TestWriting(#file_info{}),
    IsErlangServer =
        fun() ->
                TcGroupPath = proplists:get_value(tc_group_path, Config),
                {_, Path} = lists:unzip(lists:flatten(TcGroupPath)),
                lists:member(erlang_server, Path)
        end,
    case IsErlangServer() of
        true ->
            ct:log("Testing with writing a complete #file_info record"),
            {ok, FileInfo} = file:read_file_info(SftpFileName),
            TestWriting(FileInfo);
        _ ->
            %% with OpenSSH daemon started by other user above instruction end
            %% up with permission denied
            ok
    end,
    ok.

%%--------------------------------------------------------------------
file_owner_access(Config) when is_list(Config) ->
    case os:type() of
        {win32, _} ->
            {skip, "Not a relevant test on Windows"};
        _ ->
            FileName = proplists:get_value(filename, Config),
            SftpFileName = w2l(Config, FileName),
            {Sftp, _} = proplists:get_value(sftp, Config),

            {ok, #file_info{mode = InitialMode}} = ssh_sftp:read_file_info(Sftp, FileName),

            ok = ssh_sftp:write_file_info(Sftp, SftpFileName, #file_info{mode=8#000}),
            {ok, #file_info{access = none}} = ssh_sftp:read_file_info(Sftp, SftpFileName),

            ok = ssh_sftp:write_file_info(Sftp, SftpFileName, #file_info{mode=8#400}),
            {ok, #file_info{access = read}} = ssh_sftp:read_file_info(Sftp, SftpFileName),

            ok = ssh_sftp:write_file_info(Sftp, SftpFileName, #file_info{mode=8#200}),
            {ok, #file_info{access = write}} = ssh_sftp:read_file_info(Sftp, SftpFileName),

            ok = ssh_sftp:write_file_info(Sftp, SftpFileName, #file_info{mode=8#600}),
            {ok, #file_info{access = read_write}} = ssh_sftp:read_file_info(Sftp, SftpFileName),

            ok = ssh_sftp:write_file_info(Sftp, SftpFileName, #file_info{mode=InitialMode}),

            ok
    end.

%%--------------------------------------------------------------------
async_read(Config) when is_list(Config) ->
    {Sftp, _} = proplists:get_value(sftp, Config),

    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),
    {ok, Handle} = ssh_sftp:open(Sftp, SftpFileName, [read]),
    {async, Ref} = ssh_sftp:aread(Sftp, Handle, 20),

    receive
	{async_reply, Ref, {ok, Data}} ->
	    ct:log("Data: ~p~n", [Data]),
	    ok;
	Msg ->
	    ct:fail(Msg)
    after 
	30000 -> ct:fail("timeout ~p:~p",[?MODULE,?LINE])
    end.
%%--------------------------------------------------------------------
async_write(Config) when is_list(Config) ->
    {Sftp, _} = proplists:get_value(sftp, Config),
    FileName = proplists:get_value(testfile, Config),
    SftpFileName = w2l(Config, FileName),
    {ok, Handle} = ssh_sftp:open(Sftp, SftpFileName, [write]),
    Data = proplists:get_value(data, Config),
    Expected = unicode:characters_to_binary(Data),
    {async, Ref} = ssh_sftp:awrite(Sftp, Handle, Data),

    receive
	{async_reply, Ref, ok} ->
	    {ok, Expected} = file:read_file(FileName);
	Msg ->
	    ct:fail(Msg)
    end.

%%--------------------------------------------------------------------
position(Config) when is_list(Config) ->
    FileName = proplists:get_value(testfile, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),

    Data = list_to_binary("1234567890"),
    ok = ssh_sftp:write_file(Sftp, SftpFileName, Data),
    {ok, Handle} = ssh_sftp:open(Sftp, SftpFileName, [read]),

    {ok, 3} = ssh_sftp:position(Sftp, Handle, {bof, 3}),
    {ok, "4"} = ssh_sftp:read(Sftp, Handle, 1),

    {ok, 10} = ssh_sftp:position(Sftp, Handle, eof),
    eof = ssh_sftp:read(Sftp, Handle, 1),

    {ok, 6} = ssh_sftp:position(Sftp, Handle, {bof, 6}),
    {ok, "7"} = ssh_sftp:read(Sftp, Handle, 1),

    {ok, 9} = ssh_sftp:position(Sftp, Handle, {cur, 2}),
    {ok, "0"} = ssh_sftp:read(Sftp, Handle, 1),

    {ok, 0} = ssh_sftp:position(Sftp, Handle, bof),
    {ok, "1"} = ssh_sftp:read(Sftp, Handle, 1),

    {ok, 1} = ssh_sftp:position(Sftp, Handle, cur),
    {ok, "2"} = ssh_sftp:read(Sftp, Handle, 1).

read_6GB(Config) when is_list(Config) ->
    ct:timetrap(test_server:minutes(20)),
    FileName = "/dev/zero",
    SftpFileName = w2l(Config, FileName),
    {SftpChannel, _ConnectionRef} = proplists:get_value(sftp, Config),
    ChunkSize = 65535,
    N = 100000,
    {ok, Handle} = ssh_sftp:open(SftpChannel, SftpFileName, [read]),
    ExpectedList = lists:duplicate(ChunkSize, 0),
    [begin
         MBTransferred = io_lib:format("~.2f", [I * ChunkSize / 1048576.0]),
         case ssh_sftp:read(SftpChannel, Handle, ChunkSize, timer:minutes(1)) of
             {ok, ExpectedList} ->
                 [ct:log("~n~s MB read~n", [MBTransferred]) || I rem 10000 == 0];
             Result ->
                 ct:log("## After reading ~s MB~n## Unexpected result received = ~p",
                        [MBTransferred, Result]),
                 ct:fail(unexpected_reason)
         end
     end ||
        I <- lists:seq(0, N)],
    ok.

%%--------------------------------------------------------------------
pos_read(Config) when is_list(Config) ->
    FileName = proplists:get_value(testfile, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),
    Data = proplists:get_value(data_pos, Config),
    [Expect1,Expect2] = Es = [binary_to_list(unicode:characters_to_binary(D)) || D <- Data],
    [Len1,Len2] = [length(E) || E <- Es],
    ok = ssh_sftp:write_file(Sftp, SftpFileName, Data),

    {ok,Read} = file:read_file(FileName),
    ct:log("File: <~ts>~n<~p>~nExpect1: <~p>~nExpect2: <~p>", [Read, Read, Expect1, Expect2]),

    {ok,Handle} = ssh_sftp:open(Sftp, SftpFileName, [read]),
    {async,Ref} = ssh_sftp:apread(Sftp, Handle, {bof, Len1}, Len2),

    receive
	{async_reply, Ref, {ok,Expect2}} ->
	    ok;
	Msg ->
	    ct:fail(Msg)
    after 
	30000 -> ct:fail("timeout ~p:~p",[?MODULE,?LINE])
    end,

   {ok,Expect1} = ssh_sftp:pread(Sftp, Handle, {bof,0}, Len1).

%%--------------------------------------------------------------------
pos_write(Config) when is_list(Config) ->
    FileName = proplists:get_value(testfile, Config),
    SftpFileName = w2l(Config, FileName),
    {Sftp, _} = proplists:get_value(sftp, Config),

    {ok, Handle} = ssh_sftp:open(Sftp, SftpFileName, [write]),

    Data = list_to_binary("Bye,"),
    ok = ssh_sftp:write_file(Sftp, SftpFileName, [Data]),

    NewData = list_to_binary(" see you tomorrow"),
    {async, Ref} = ssh_sftp:apwrite(Sftp, Handle, {bof, 4}, NewData),
    receive
	{async_reply, Ref, ok} ->
	    ok;
	Msg ->
	    ct:fail(Msg)
    after 
	30000 -> ct:fail("timeout ~p:~p",[?MODULE,?LINE])
    end,

    LastData = proplists:get_value(data, Config),
    ok = ssh_sftp:pwrite(Sftp, Handle, eof, LastData),

    NewData1 = unicode:characters_to_binary("Bye, see you tomorrow" ++ LastData),
    {ok, NewData1} = ssh_sftp:read_file(Sftp, SftpFileName).

%%--------------------------------------------------------------------
start_channel_sock(Config) ->
    LoginOpts =
	case proplists:get_value(group,Config) of
	    erlang_server -> 
		[{user,     proplists:get_value(user, Config)},
		 {password, proplists:get_value(passwd, Config)}];
	    openssh_server ->
		[] % Use public key
	end,

    Opts = [{user_interaction, false},
	    {silently_accept_hosts, true},
            {save_accepted_host, false}
	    | LoginOpts],

    {Host,Port} = proplists:get_value(peer, Config),

    %% Get a tcp socket
    {ok, Sock} = ssh_test_lib:gen_tcp_connect(Host, Port, [{active,false}]),

    %% and open one channel on one new Connection
    {ok, ChPid1, Conn} = ssh_sftp:start_channel(Sock, Opts),
    
    %% Test that the channel is usable
    FileName = proplists:get_value(filename, Config),
    SftpFileName = w2l(Config, FileName),

    ok = open_close_file(ChPid1, SftpFileName, [read]),
    ok = open_close_file(ChPid1, SftpFileName, [write]),

    %% Try to open a second channel on the Connection
    {ok, ChPid2} = ssh_sftp:start_channel(Conn, Opts),
    ok = open_close_file(ChPid1, SftpFileName, [read]),
    ok = open_close_file(ChPid2, SftpFileName, [read]),

    %% Test that the second channel still works after closing the first one
    ok = ssh_sftp:stop_channel(ChPid1),
    ok = open_close_file(ChPid2, SftpFileName, [write]),
    
    %% Test the Connection survives that all channels are closed
    ok = ssh_sftp:stop_channel(ChPid2),
    {ok, ChPid3} = ssh_sftp:start_channel(Conn, Opts),
    ok = open_close_file(ChPid3, SftpFileName, [write]),
    
    %% Test that a closed channel really is closed
    {error, closed} = ssh_sftp:open(ChPid2, SftpFileName, [write]),
    ok = ssh_sftp:stop_channel(ChPid3),

    %% Test that the socket is closed when the Connection closes
    ok = ssh:close(Conn),
    timer:sleep(400), %% Until the stop sequence is fixed
    {error,_} = inet:getopts(Sock, [active]),

    ok.

%%--------------------------------------------------------------------
sftp_nonexistent_subsystem(Config) when is_list(Config) ->
    {_,Host, Port} =  proplists:get_value(sftpd, Config),
    User = proplists:get_value(user, Config),
    Passwd = proplists:get_value(passwd, Config),
    {error,"server failed to start sftp subsystem"} =
	ssh_sftp:start_channel(Host, Port,
			       [{user_interaction, false},
				{user, User},
				{password, Passwd},
				{silently_accept_hosts, true},
                                {save_accepted_host, false}
                               ]).

%%--------------------------------------------------------------------
version_option(Config) when is_list(Config) ->
    open_close_dir(Config).

%%--------------------------------------------------------------------
create_empty_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    erl_tar:close(Handle),
    {ChPid,_} = proplists:get_value(sftp,Config),
    {ok, #file_info{type=regular}} =
	ssh_sftp:read_file_info(ChPid, SftpTarFileName).

%%--------------------------------------------------------------------
files_to_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    F1 = proplists:get_value(tar_F1_txt, Config),
    ok = erl_tar:add(Handle, fn(F1,Config), F1, [verbose]),
    ok = erl_tar:add(Handle, fn("f2.txt",Config), "f2.txt", [verbose]),
    ok = erl_tar:close(Handle),
    chk_tar([F1, "f2.txt"], Config).

%%--------------------------------------------------------------------
ascii_filename_ascii_contents_to_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    ok = erl_tar:add(Handle, fn("f2.txt",Config), "f2.txt", [verbose]),
    ok = erl_tar:close(Handle),
    chk_tar(["f2.txt"], Config).

%%--------------------------------------------------------------------
ascii_filename_unicode_contents_to_tar(Config) ->
    case proplists:get_value(tar_F3_txt, Config) of
	undefined ->
	    {skip, "Unicode test"};
	Fn ->
	    ChPid2 = proplists:get_value(channel_pid2, Config),
	    TarFileName = proplists:get_value(tar_filename, Config),
            SftpTarFileName = w2l(Config, TarFileName),
	    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
	    ok = erl_tar:add(Handle, fn(Fn,Config), Fn, [verbose]),
	    ok = erl_tar:close(Handle),
	    chk_tar([Fn], Config)
    end.

%%--------------------------------------------------------------------
unicode_filename_ascii_contents_to_tar(Config) ->
    case proplists:get_value(tar_F4_txt, Config) of
	undefined ->
	    {skip, "Unicode test"};
	Fn ->
	    ChPid2 = proplists:get_value(channel_pid2, Config),
	    TarFileName = proplists:get_value(tar_filename, Config),
            SftpTarFileName = w2l(Config, TarFileName),
	    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
	    ok = erl_tar:add(Handle, fn(Fn,Config), Fn, [verbose]),
	    ok = erl_tar:close(Handle),
	    chk_tar([Fn], Config)
    end.

%%--------------------------------------------------------------------
big_file_to_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]), 
    ok = erl_tar:add(Handle, fn("big.txt",Config), "big.txt", [verbose]),
    ok = erl_tar:close(Handle),
    chk_tar(["big.txt"], Config).


%%--------------------------------------------------------------------
files_chunked_to_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    F1 = proplists:get_value(tar_F1_txt, Config),
    ok = erl_tar:add(Handle, fn(F1,Config), F1, [verbose,{chunks,2}]),
    ok = erl_tar:close(Handle),
    chk_tar([F1], Config).

%%--------------------------------------------------------------------
directory_to_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    ok = erl_tar:add(Handle, fn("d1",Config), "d1", [verbose]),
    ok = erl_tar:close(Handle),
    chk_tar(["d1"], Config).

%%--------------------------------------------------------------------
binaries_to_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    Bin = <<"A binary">>,
    ok = erl_tar:add(Handle, Bin, "b1", [verbose]),
    ok = erl_tar:close(Handle),
    chk_tar([{"b1",Bin}], Config).

%%--------------------------------------------------------------------
null_crypto_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    Cinit = fun() -> {ok, no_state, _SendSize=5} end,
    Cenc = fun(Bin,CState) -> {ok,Bin,CState,_SendSize=5} end,
    Cend = fun(Bin,_CState) -> {ok,Bin} end,
    C = {Cinit,Cenc,Cend},
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write,{crypto,C}]),
    Bin = <<"A binary">>,
    F1 = proplists:get_value(tar_F1_txt, Config),
    ok = erl_tar:add(Handle, Bin, "b1", [verbose]),
    ok = erl_tar:add(Handle, fn(F1,Config), F1, [verbose,{chunks,2}]),
    ok = erl_tar:add(Handle, fn("big.txt",Config), "big.txt", [verbose,{chunks,15000}]),
    ok = erl_tar:close(Handle),
    chk_tar([{"b1",Bin}, F1, "big.txt"], Config).

%%--------------------------------------------------------------------
simple_crypto_tar_small(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    Cinit = fun() -> {ok, no_state, _Size=6} end,
    Cenc = fun(Bin,CState) -> {ok,stuff(Bin),CState,_SendSize=5} end,
    Cdec = fun(Bin,CState) -> {ok,unstuff(Bin),CState,_Size=4} end,
    Cend = fun(Bin,_CState) -> {ok,stuff(Bin)} end,
    C = {Cinit,Cenc,Cend},
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write,{crypto,C}]),
    Bin = <<"A binary">>,
    F1 = proplists:get_value(tar_F1_txt, Config),
    ok = erl_tar:add(Handle, Bin, "b1", [verbose]),
    ok = erl_tar:add(Handle, fn(F1,Config), F1, [verbose,{chunks,2}]),
    ok = erl_tar:close(Handle),
    chk_tar([{"b1",Bin}, F1], Config, [{crypto,{Cinit,Cdec}}]).

%%--------------------------------------------------------------------
simple_crypto_tar_big(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    Cinit = fun() -> {ok, no_state, _SendSize=6} end,
    Cenc = fun(Bin,CState) -> {ok,stuff(Bin),CState,_SendSize=5} end,
    Cdec = fun(Bin,CState) -> {ok,unstuff(Bin),CState,_SendSize=4} end,
    Cend = fun(Bin,_CState) -> {ok,stuff(Bin)} end,
    C = {Cinit,Cenc,Cend},
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,Handle} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write,{crypto,C}]),
    Bin = <<"A binary">>,
    F1 = proplists:get_value(tar_F1_txt, Config),
    ok = erl_tar:add(Handle, Bin, "b1", [verbose]),
    ok = erl_tar:add(Handle, fn(F1,Config), F1, [verbose,{chunks,2}]),
    ok = erl_tar:add(Handle, fn("big.txt",Config), "big.txt", [verbose,{chunks,15000}]),
    ok = erl_tar:close(Handle),
    chk_tar([{"b1",Bin}, F1, "big.txt"], Config, [{crypto,{Cinit,Cdec}}]).

stuff(Bin) -> << <<C,C>> || <<C>> <= Bin >>.

unstuff(Bin) -> << <<C>> || <<C,C>> <= Bin >>.

%%--------------------------------------------------------------------
read_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    NameBins = lists:sort(
		 [{"b1",<<"A binary">>},
		  {"b2",list_to_binary(lists:duplicate(750000,"a"))}
		 ]),
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,HandleWrite} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write]),
    [ok = erl_tar:add(HandleWrite, Bin, Name, [verbose])
     ||	{Name,Bin} <- NameBins],
    ok = erl_tar:close(HandleWrite),

    chk_tar(NameBins, Config).

%%--------------------------------------------------------------------
read_null_crypto_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    NameBins = lists:sort(
		 [{"b1",<<"A binary">>},
		  {"b2",list_to_binary(lists:duplicate(750000,"a"))}
		 ]),
    Cinitw = fun() -> {ok, no_state, _SendSize=5} end,
    Cinitr = fun() -> {ok, no_state, _FetchSize=42} end,
    Cenc = fun(Bin,CState) -> {ok,Bin,CState,_SendSize=42*42} end,
    Cdec = fun(Bin,CState) -> {ok,Bin,CState,_FetchSize=19} end,
    Cendw = fun(Bin,_CState) -> {ok,Bin} end,
    Cw = {Cinitw,Cenc,Cendw},
    Cr = {Cinitr,Cdec},

    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,HandleWrite} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write,{crypto,Cw}]),
    [ok = erl_tar:add(HandleWrite, Bin, Name, [verbose])
     ||	{Name,Bin} <- NameBins],
    ok = erl_tar:close(HandleWrite),

    chk_tar(NameBins, Config, [{crypto,Cr}]).

%%--------------------------------------------------------------------
read_crypto_tar(Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    NameBins = lists:sort(
		 [{"b1",<<"A binary">>},
		  {"b2",list_to_binary(lists:duplicate(750000,"a"))}
		 ]),
    Cinitw = fun() -> {ok, no_state, _SendSize=5} end,
    Cinitr = fun() -> {ok, no_state, _FetchSize=42} end,

    Cenc = fun(Bin,CState) -> {ok,stuff(Bin),CState,_SendSize=42*42} end,
    Cdec = fun(Bin,CState) -> {ok,unstuff(Bin),CState,_FetchSize=120} end,
    Cendw = fun(Bin,_CState) -> {ok,stuff(Bin)} end,
    Cw = {Cinitw,Cenc,Cendw},
    Cr = {Cinitr,Cdec},

    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),
    {ok,HandleWrite} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write,{crypto,Cw}]),
    [ok = erl_tar:add(HandleWrite, Bin, Name, [verbose])
     ||	{Name,Bin} <- NameBins],
    ok = erl_tar:close(HandleWrite),

    chk_tar(NameBins, Config, [{crypto,Cr}]).

%%--------------------------------------------------------------------
block_size_16_crypto_tar(Config) -> cipher_crypto_tar(aes_256_cbc, Config).
block_size_1_crypto_tar(Config) -> cipher_crypto_tar(aes_256_ctr, Config).

cipher_crypto_tar(Cipher, Config) ->
    ChPid2 = proplists:get_value(channel_pid2, Config),
    NameBins = lists:sort(
		 [{"b1",<<"A binary">>},
		  {"b2",list_to_binary(lists:duplicate(750000,"a"))},
		  {"d1",fn("d1",Config)}  % Dir
		 ]),
    Key = <<"This is a 256 bit key. Boring...">>,
    Ivec0 = crypto:strong_rand_bytes(16),

    Cinitw = fun() -> {ok, crypto:crypto_init(Cipher,Key,Ivec0,[{encrypt,true},
                                                                {padding,zero}])} end,
    Cinitr = fun() -> {ok, crypto:crypto_init(Cipher,Key,Ivec0,false)} end,

    Cenc = fun(PlainBin,State) -> 
		   CipherBin = crypto:crypto_update(State, PlainBin),
		   {ok, CipherBin, State}
	   end,
    Cdec = fun(CipherBin,State) ->
		   PlainBin = crypto:crypto_update(State, CipherBin),
		   {ok, PlainBin, State}
	   end,

    Cendw = fun(PlainBin, State) ->
                    CipherBin1 = crypto:crypto_update(State, PlainBin),
                    Sz1 = size(CipherBin1),
		    CipherBin2 = crypto:crypto_final(State),
                    Sz2 = size(CipherBin2),
		    {ok, <<CipherBin1:Sz1/binary, CipherBin2:Sz2/binary>>}
	    end,

    Cw = {Cinitw,Cenc,Cendw},
    TarFileName = proplists:get_value(tar_filename, Config),
    SftpTarFileName = w2l(Config, TarFileName),

    {ok,HandleWrite} = ssh_sftp:open_tar(ChPid2, SftpTarFileName, [write,{crypto,Cw}]),
    [ok = erl_tar:add(HandleWrite, Bin, Name, [verbose]) || {Name,Bin} <- NameBins],
    ok = erl_tar:close(HandleWrite),

    Cr = {Cinitr,Cdec},
    chk_tar(NameBins, Config, [{crypto,Cr}]).

%%--------------------------------------------------------------------
%% Internal functions ------------------------------------------------
%%--------------------------------------------------------------------
have_unicode_support() -> (file:native_name_encoding() == utf8) andalso ("四" == [22235]).


make_data_sub_dir(Config, SubDirSrc, SubDirDst) ->
    SrcDir = filename:join(proplists:get_value(data_dir, Config),
                           SubDirSrc
                          ),
    DstDir = filename:join(proplists:get_value(data_dir, Config),
                           SubDirDst),
    ssh_test_lib:copy_recursive(SrcDir, DstDir),
    {ok,DstDir}.
    

prepare(Config0) ->
    SrcDir = proplists:get_value(datadir_tar,Config0),
    DstDir = filename:join(proplists:get_value(priv_dir,Config0), ssh_test_lib:random_chars(10)),
    ssh_test_lib:copy_recursive(SrcDir, DstDir),
    Keys = [filename,
	    testfile,
	    linktest,
	    tar_filename],
    Config1 = foldl_keydelete(Keys, Config0),
    Config2 = lists:foldl(fun({Key,Name}, ConfAcc) ->
                                  [{Key, filename:join(DstDir,Name)} | ConfAcc]
			  end,
			  Config1,
                          lists:zip(Keys, [proplists:get_value(K,Config0) || K<-Keys])),

    catch ct:log("~p:~p Prepared filenames (Key -> Value):~n~ts",
                 [?MODULE,?LINE,
                  [io_lib:format("~p -> ~ts~n", [K,V]) || {K,V} <- Config2,
                                                          lists:member(K, Keys)]]),

    DataDir =  proplists:get_value(data_dir, Config2),
    FilenameSrc = filename:join(DataDir, "sftp.txt"),
    FilenameDst = proplists:get_value(filename, Config2),
    {ok,_} = file:copy(FilenameSrc, FilenameDst),
    [{sftp_priv_dir,DstDir} | Config2].


foldl_keydelete(Keys, L) ->
    lists:foldl(fun(K,E) -> lists:keydelete(K,1,E) end, 
		L,
		Keys).


chk_tar(Items, Config) ->
    chk_tar(Items, Config, []).

chk_tar(Items, Config, Opts) ->
    TarFileName = proplists:get_value(tar_filename, Config),
    chk_tar(Items, TarFileName, Config, Opts).

chk_tar(Items, TarFileName, Config, Opts)  when is_list(Opts) ->
    SftpTarFileName = w2l(Config, TarFileName),
    tar_size(TarFileName, Config),
    {ChPid,_} = proplists:get_value(sftp,Config),
    {ok,HandleRead} = ssh_sftp:open_tar(ChPid, SftpTarFileName, [read|Opts]),
    {ok,NameValueList} = erl_tar:extract(HandleRead,[memory,verbose]),
    ok = erl_tar:close(HandleRead),
    case {lists:sort(expand_items(Items,Config)), lists:sort(NameValueList)} of
	{L,L} -> 
	    true;
	{Expect,Actual} -> 
	    ct:log("Expect: ~p",[Expect]), ct:log("Actual: ~p",[Actual]),
	    case erl_tar:table(TarFileName) of
		{ok,Names} -> ct:log("names: ~p",[Names]);
		Other -> ct:log("~p",[Other])
	    end,
	    ct:log("~s",[analyze_report(Expect, Actual)]),
	    ct:fail(bad_tar_contents)
    end.

analyze_report([E={NameE,BinE}|Es], [A={NameA,BinA}|As]) ->
    if
	NameE == NameA,
	BinE =/= BinA-> 
	    [["Component ",NameE," differs. \n  Expected: ",BinE,"\n  Actual: ",BinA,"\n\n"]
	     | analyze_report(Es,As)];

	NameE < NameA ->
	    [["Component ",NameE," is missing.\n\n"]
	     | analyze_report(Es,[A|As])];

	NameE > NameA ->
	    [["Component ",NameA," is not expected.\n\n"]
	     | analyze_report([E|Es],As)];
	true ->
	    analyze_report(Es, As)
    end;
analyze_report([{NameE,_BinE}|Es], []) ->
    [["Component ",NameE," missing.\n\n"] | analyze_report(Es,[])];
analyze_report([], [{NameA,_BinA}|As]) ->
    [["Component ",NameA," not expected.\n\n"] | analyze_report([],As)];
analyze_report([], []) ->
    "".

tar_size(TarFileName, Config) ->
    SftpTarFileName = w2l(Config, TarFileName),
    {ChPid,_} = proplists:get_value(sftp,Config),
    {ok,Data} = ssh_sftp:read_file(ChPid, SftpTarFileName),
    io:format('Tar file ~p is~n ~p bytes.~n',[TarFileName, size(Data)]).

expand_items(Items, Config) ->    
    lists:flatten(
      [case Item of
	   {_Name,Bin} when is_binary(Bin) -> 
	       Item;
	   {Name,FileName} when is_list(FileName) ->
	       read_item_contents(Name, fn(FileName,Config));
	   FileName  when is_list(FileName) ->
	       read_item_contents(FileName, fn(FileName,Config))
       end || Item <- Items]).

read_item_contents(ItemName, FileName) ->
    case file:read_file(FileName) of
	{ok,Bin} ->
	    {ItemName, Bin};
	{error,eisdir} ->
	    {ok,FileNames} = file:list_dir(FileName),
	    [read_item_contents(filename:join(ItemName,Name),
				filename:join(FileName,Name)) 
	     || Name<-FileNames]
    end.

fn(Name, Config) ->
    Dir = proplists:get_value(datadir_tar, Config),
    filename:join(Dir,Name).

fmt_host({A,B,C,D}) -> lists:concat([A,".",B,".",C,".",D]);
fmt_host(S) -> S.


%%%----------------------------------------------------------------
populate_non_unicode(Dir) ->
    file:delete("f1.txt"),
    ok = file:write_file(filename:join(Dir,"f3.txt"),
                         unicode:characters_to_binary("你好")),
    ok = file:write_file(filename:join(Dir,"F一.txt"),
                         unicode:characters_to_binary("你好")),
    ok = file:write_file(filename:join(Dir,"g四.txt"),
                         <<"How are you?">>).

w2l(P) ->
    ssh_test_lib:winpath_to_linuxpath(P).

w2l(Config, P) ->
    W2L = proplists:get_value(w2l, Config, fun(X) -> X end),
    W2L(P).

verify_openssh(Config) ->
    ct:comment("Begin ~p",[grps(Config)]),
    Host = ssh_test_lib:hostname(),
    case (catch ssh_sftp:start_channel(Host,
				       [{user_interaction, false},
					{silently_accept_hosts, true},
                                        {save_accepted_host, false}
                                       ])) of
	{ok, _ChannelPid, Connection} ->
	    [{peer, {_HostName,{IPx,Portx}}}] = ssh:connection_info(Connection,[peer]),
	    ssh:close(Connection),
	    [{w2l, fun w2l/1},
             {peer, {fmt_host(IPx),Portx}}, {group, openssh_server} | Config];
	{error,"Key exchange failed"} ->
	    {skip, "openssh server doesn't support the tested kex algorithm"};
	Other ->
            ct:log("No openssh server. Cause:~n~p~n",[Other]),
	    {skip, "No openssh daemon (see log in testcase)"}
    end.
