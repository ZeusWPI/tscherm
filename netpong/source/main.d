// Try with: ping -c1 -s 15 -p 4e4554504f4e472100400006000800 -c1 [remote]
// magic: 4e4554504f4e4721
// type: 00   (ubyte)
// yPos: 4000 (LE short)
// xVel: 0600 (LE short)
// yVel: 0800 (LE short)
module main;

import pong : Pong;

import argparse;

struct Config
{
    @(NamedArgument(["i", "interface"]).Required)
    string network_interface;

    @(NamedArgument(["l", "local"]).Required)
    string local_address;

    @(NamedArgument(["r", "remote"]).Required)
    string remote_address;
}

mixin CLI!Config.main!((Config config)
{
    Pong* pong = new Pong(config.network_interface, config.local_address, config.remote_address);
    pong.run;
});