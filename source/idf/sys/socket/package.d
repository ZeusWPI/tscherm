module idf.sys.socket;

public import idf.sys.socket.idf_sys_socket_c_code;

@safe:

ushort htons(ushort hostShort) @trusted => htonsCFunc(hostShort);
uint htonl(uint hostInt) @trusted => htonlCFunc(hostInt);
