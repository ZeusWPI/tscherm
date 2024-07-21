module idf.sys.socket;

public import idf.sys.socket.idf_sys_socket_c_code;

@safe nothrow @nogc:

alias htons = htonsCFunc;
alias htonl = htonlCFunc;
