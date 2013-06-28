-module(node_server).
-compile(export_all).
-include_lib("kvs/include/users.hrl").

login(User,Pass) ->
    Res = kvs:get(user,User),
    case Res of
        {ok,#user{username=User,password=Pass}} -> 
            Token = erlang:md5(term_to_binary({now(),make_ref()})),
            ets:insert(accounts,{Token,User}),
            Token;
        _ -> skip end.

create(User,Token,Cpu,Ram,Cert,Ports) ->
    case auth(User,Token) of
         ok -> create_box(User,Cpu,Ram,Cert,Ports);
         Error -> Error end.


make_pass() ->
    Res = os:cmd("makepasswd --char=12"),
    [Pass] = string:tokens(Res,"\n"),
    Pass.

make_template(Hostname,User,Pass) ->
    erlydtl:compile(code:priv_dir(ins) ++ "/" ++ "Dockerfile.template",docker_template),
    {ok,File} = docker_template:render([{password,Pass}]),
    os:cmd(["mkdir -p users/",User,"-",Hostname]),
    file:write_file(["users/",User,"-",Hostname,"/Dockerfile"], File).

docker_build(Hostname,User) ->
    Res = os:cmd(["docker build users/",User,"-",Hostname]),
    error_logger:info_msg("Tokens: ~p",[Res]),
    Tokens = string:tokens(Res,"\n"),
    [Success,Id,LXC|Rest] = lists:reverse(Tokens),
    error_logger:info_msg("LCX: ~p",[LXC]),
    Running = string:tokens(LXC," "),
    hd(lists:reverse(Running)).

docker_commit(Id,Hostname,User) -> os:cmd(["docker commit ",Id," voxoz/",User,"-",Hostname]).
docker_push(Hostname,User) -> os:cmd(["docker push voxoz/",User,"-",Hostname]).

docker_run(Hostname,User,Cpu,Ram,Ports) ->
    P = string:join([ "-p " ++ integer_to_list(Port) || Port <- Ports], " "),
    Cmd = ["docker run -d ",P," -c=",integer_to_list(Cpu),
                              " -h=\"",Hostname,"\" voxoz/",User,"-",Hostname,
                        " /usr/bin/supervisord -n"],
    error_logger:info_msg(Cmd),
    Res = os:cmd(Cmd),
    error_logger:info_msg(Cmd),
    Tokens = string:tokens(Res,"\n"),
    hd(Tokens).

docker_port(Id,Port) ->
    Res = os:cmd(["docker port ",Id," ",integer_to_list(Port)]),
    [Tokens] = string:tokens(Res,"\n"),
    list_to_integer(Tokens).

% LXC creation schema

% ports: 22, 80, 2000
% user: maxim
% cpu: 8
% ram: 128000000

% makepasswd --char=12
% > L96QBmh21gKb
% docker build .
% >  ---> Running in e2f2668a6ab5
% >  ---> 79f6c9f416d2
% > Successfully built 79f6c9f416d2
% docker commit e2f2668a6ab5 synrc/sncn1
% docker push synrc/sncn1
% docker run -d -p 22 -p 80 -c=8 -m=128000000 synrc/sncn1 /usr/bin/supervisor -n
% > b33e7a0a354c
% docker port b33e7a0a354c 22
% > 49158
% docker port b33e7a0a354c 80
% > 49159

% mail: IP=do1.synrc.com, ROOT_PASS=L96QBmh21gKb, NAME=sncn1, ID=387ba01740ed, SSH_PORT=49158

create_box(User,Cpu,Ram,Cert,Ports) ->
    Pass = make_pass(),
    Hostname = make_pass(),
    make_template(Hostname,User,Pass),
    LXC = docker_build(Hostname,User),
    docker_commit(LXC,Hostname,User),
    docker_push(Hostname,User),
    Id = docker_run(Hostname,User,Cpu,Ram,Ports),
    Port = docker_port(Id,22),
    {Id,Port,User,Hostname,Pass}.

auth(User,Token) ->
    case ets:lookup(accounts,Token) of
         [{_,User}] -> ok;
         _ -> error end.
