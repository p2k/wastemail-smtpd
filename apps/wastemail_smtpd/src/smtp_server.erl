
%%
%% Copyright (C) 2011  Patrick "p2k" Schneider <patrick.p2k.schneider@gmail.com>
%%
%% This file is part of WasteMail SMTPd.
%%
%% WasteMail SMTPd is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.
%%
%% WasteMail SMTPd is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with WasteMail SMTPd.  If not, see <http://www.gnu.org/licenses/>.
%%

-module(smtp_server).
-behaviour(gen_smtp_server_session).

-export([start_link/0, init/4, handle_HELO/2, handle_EHLO/3, handle_MAIL/2, handle_MAIL_extension/2,
        handle_RCPT/2, handle_RCPT_extension/2, handle_DATA/4, handle_RSET/1, handle_VRFY/2,
        handle_other/3, code_change/3, terminate/2]).

-record(state, {options = []}).

start_link() ->
    %gen_smtp_server:start(?MODULE, [[{port, 25}], [{protocol, ssl}, {port, 465}], [{family, inet6}, {address, "::"}]]).
    gen_smtp_server:start_link(?MODULE).

init(Hostname, SessionCount, Address, Options) ->
    io:format("peer: ~p~n", [Address]),
    if
        SessionCount =< 20 ->
            Banner = [Hostname, " WasteMail SMTPd"],
            State = #state{options = Options},
            {ok, Banner, State};
        true ->
            io:format("Connection limit exceeded~n"),
            {stop, normal, ["421 ", Hostname, " is too busy to accept mail right now"]}
    end.

handle_HELO(<<"invalid">>, State) ->
    {error, "554 invalid hostname", State};
handle_HELO(<<"trusted_host">>, State) ->
    {ok, State};
handle_HELO(Hostname, State) ->
    io:format("HELO from \"~s\"~n", [Hostname]),
    {ok, 655360, State}.

handle_EHLO(<<"invalid">>, _Extensions, State) ->
    {error, "554 invalid hostname", State};
handle_EHLO(Hostname, Extensions, State) ->
    io:format("EHLO from \"~s\"~n", [Hostname]),
    {ok, Extensions, State}.

handle_MAIL(From, State) ->
    io:format("Mail from <~s>~n", [From]),
    {ok, State}.

handle_MAIL_extension(Extension, _State) ->
    io:format("Unknown MAIL FROM extension \"~s\"~n", [Extension]),
    error.

handle_RCPT(To, State) ->
    io:format("Mail to <~s>~n", [To]),
    {ok, State}.

handle_RCPT_extension(Extension, _State) ->
    io:format("Unknown RCPT TO extension \"~s\"~n", [Extension]),
    error.

handle_DATA(_From, _To, <<>>, State) ->
    {error, "552 Message too small", State};
handle_DATA(From, To, Data, State) ->
    Reference = "-",
    io:format("message from <~s> to <~s> queued as \"~s\", body length ~p~n", [From, To, Reference, byte_size(Data)]),
    try mimemail:decode(Data) of
        Result ->
            io:format("Message decoded successfully! Result:~n~p~n", [Result])
    catch
        What:Why ->
            io:format("Message decode FAILED with ~p:~p~n", [What, Why]),
            ok
    end,
    {ok, Reference, State}.

handle_RSET(State) ->
    State.

handle_VRFY(_Address, State) ->
    {error, "252 VRFY disabled by policy, just send some mail", State}.

handle_other(Verb, _Args, State) ->
    {["500 Error: command not recognized : '", Verb, "'"], State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(Reason, State) ->
    {ok, Reason, State}.

%%% Internal Functions %%%

