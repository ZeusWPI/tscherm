module idf.errno;

@safe nothrow @nogc:

extern (C) int* __errno();
int errno(_ = void)() => *__errno;

// dfmt off
enum int EPERM     = 1;  /// Not owner
enum int ENOENT    = 2;  /// No such file or directory
enum int ESRCH     = 3;  /// No such process
enum int EINTR     = 4;  /// Interrupted system call
enum int EIO       = 5;  /// I/O error
enum int ENXIO     = 6;  /// No such device or address
enum int E2BIG     = 7;  /// Arg list too long
enum int ENOEXEC   = 8;  /// Exec format error
enum int EBADF     = 9;  /// Bad file number
enum int ECHILD    = 10; /// No children
enum int EAGAIN    = 11; /// No more processes
enum int ENOMEM    = 12; /// Not enough space
enum int EACCES    = 13; /// Permission denied
enum int EFAULT    = 14; /// Bad address
enum int EBUSY     = 16; /// Device or resource busy
enum int EEXIST    = 17; /// File exists
enum int EXDEV     = 18; /// Cross-device link
enum int ENODEV    = 19; /// No such device
enum int ENOTDIR   = 20; /// Not a directory
enum int EISDIR    = 21; /// Is a directory
enum int EINVAL    = 22; /// Invalid argument
enum int ENFILE    = 23; /// Too many open files in system
enum int EMFILE    = 24; /// File descriptor value too large
enum int ENOTTY    = 25; /// Not a character device
enum int ETXTBSY   = 26; /// Text file busy
enum int EFBIG     = 27; /// File too large
enum int ENOSPC    = 28; /// No space left on device
enum int ESPIPE    = 29; /// Illegal seek
enum int EROFS     = 30; /// Read-only file system
enum int EMLINK    = 31; /// Too many links
enum int EPIPE     = 32; /// Broken pipe
enum int EDOM      = 33; /// Mathematics argument out of domain of function
enum int ERANGE    = 34; /// Result too large
enum int ENOMSG    = 35; /// No message of desired type
enum int EIDRM     = 36; /// Identifier removed
enum int EDEADLK   = 45; /// Deadlock
enum int ENOLCK    = 46; /// No lock
enum int ENOSTR    = 60; /// Not a stream
enum int ENODATA   = 61; /// No data (for no delay io)
enum int ETIME     = 62; /// Stream ioctl timeout
enum int ENOSR     = 63; /// No stream resources
enum int ENONET    = 64; /// Machine is not on the network
enum int ENOPKG    = 65; /// Package not installed
enum int EREMOTE   = 66; /// The object is remote
enum int ENOLINK   = 67; /// Virtual circuit is gone
enum int EADV      = 68; /// Advertise error
enum int ESRMNT    = 69; /// Srmount error
enum int ECOMM     = 70; /// Communication error on send
enum int EPROTO    = 71; /// Protocol error
enum int EMULTIHOP = 74; /// Multihop attempted
enum int ELBIN     = 75; /// Inode is remote (not really error)
enum int EDOTDOT   = 76; /// Cross mount point (not really error)
enum int EBADMSG   = 77; /// Bad message
enum int EFTYPE    = 79; /// Inappropriate file type or format
enum int ENOTUNIQ  = 80; /// Given log. name not unique
enum int EBADFD    = 81; /// f.d. invalid for this operation
enum int EREMCHG   = 82; /// Remote address changed
enum int ELIBACC   = 83; /// Can't access a needed shared lib
enum int ELIBBAD   = 84; /// Accessing a corrupted shared lib
enum int ELIBSCN   = 85; /// .lib section in a.out corrupted
enum int ELIBMAX   = 86; /// Attempting to link in too many libs
enum int ELIBEXEC  = 87; /// Attempting to exec a shared library
enum int ENOSYS    = 88; /// Function not implemented
enum int ENMFILE   = 89; /// No more files
enum int ENOTEMPTY = 90; /// Directory not empty
enum int ENAMETOOLONG    = 91;  /// File or path name too long
enum int ELOOP           = 92;  /// Too many symbolic links
enum int EOPNOTSUPP      = 95;  /// Operation not supported on socket
enum int EPFNOSUPPORT    = 96;  /// Protocol family not supported
enum int ECONNRESET      = 104; /// Connection reset by peer
enum int ENOBUFS         = 105; /// No buffer space available
enum int EAFNOSUPPORT    = 106; /// Address family not supported by protocol family
enum int EPROTOTYPE      = 107; /// Protocol wrong type for socket
enum int ENOTSOCK        = 108; /// Socket operation on non-socket
enum int ENOPROTOOPT     = 109; /// Protocol not available
enum int ESHUTDOWN       = 110; /// Can't send after socket shutdown
enum int ECONNREFUSED    = 111; /// Connection refused
enum int EADDRINUSE      = 112; /// Address already in use
enum int ECONNABORTED    = 113; /// Software caused connection abort
enum int ENETUNREACH     = 114; /// Network is unreachable
enum int ENETDOWN        = 115; /// Network interface is not configured
enum int ETIMEDOUT       = 116; /// Connection timed out
enum int EHOSTDOWN       = 117; /// Host is down
enum int EHOSTUNREACH    = 118; /// Host is unreachable
enum int EINPROGRESS     = 119; /// Connection already in progress
enum int EALREADY        = 120; /// Socket already connected
enum int EDESTADDRREQ    = 121; /// Destination address required
enum int EMSGSIZE        = 122; /// Message too long
enum int EPROTONOSUPPORT = 123; /// Unknown protocol
enum int ESOCKTNOSUPPORT = 124; /// Socket type not supported
enum int EADDRNOTAVAIL   = 125; /// Address not available
enum int ENETRESET       = 126; /// Connection aborted by network
enum int EISCONN         = 127; /// Socket is already connected
enum int ENOTCONN        = 128; /// Socket is not connected
enum int ETOOMANYREFS    = 129;
enum int EPROCLIM        = 130;
enum int EUSERS          = 131;
enum int EDQUOT          = 132;
enum int ESTALE          = 133;
enum int ENOTSUP         = 134; /// Not supported
enum int ENOMEDIUM       = 135; /// No medium (in tape drive)
enum int ENOSHARE        = 136; /// No such host or network path
enum int ECASECLASH      = 137; /// Filename exists with different case
enum int EILSEQ          = 138; /// Illegal byte sequence
enum int EOVERFLOW       = 139; /// Value too large for defined data type
enum int ECANCELED       = 140; /// Operation canceled
enum int ENOTRECOVERABLE = 141; /// State not recoverable
enum int EOWNERDEAD      = 142; /// Previous owner died
enum int ESTRPIPE        = 143; /// Streams pipe error

enum int EWOULDBLOCK = EAGAIN; /// Operation would block

enum int __ELASTERROR      = 2000;  /// Users can add values starting here
