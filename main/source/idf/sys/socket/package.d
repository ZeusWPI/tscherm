module idf.sys.socket;

public import idf.sys.socket.idf_sys_socket_c_code;
import core.internal.traits;

@safe:

ushort htons(ushort hostShort) @trusted => htonsCFunc(hostShort);
