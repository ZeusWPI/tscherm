module main;

import pong : Pong;

import core.stdc.stdlib : exit;

import std.stdio : stderr, writefln;

import argparse;

struct Config
{
    @(NamedArgument(["i", "interface"]).Required)
    string network_interface;

    @(NamedArgument(["l", "local"]).Required)
    string local_host;

    @(NamedArgument(["r", "remote"]).Required)
    string remote_host;

    @(NamedArgument(["a", "accept-echo-reply"]).Optional)
    bool accept_echo_reply;
}

mixin CLI!Config.main!((Config config) {
    try
    {
        Pong* pong = new Pong(
            config.network_interface,
            config.local_host,
            config.remote_host,
            config.accept_echo_reply,
        );
        pong.run;
    }
    catch (Exception e)
    {
        stderr.writefln!"Caught exception in main: %s"(e);
        exit(1);
    }
});
