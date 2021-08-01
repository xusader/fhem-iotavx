#
# 98_IOTAVX.pm
#

package main;

use strict;
use warnings;
use DevIo; # load DevIo.pm if not already loaded
use Time::HiRes qw(gettimeofday);

my %IOTAVX_set = (
"input" => {
            "TV(ARC)"   => q('@11B'),
            "HDMI1"     => q('@116'),
            "HDMI2"     => q('@115'),
            "HDMI3"     => q('@15A'),
            "HDMI4"     => q('@15B'),
            "HDMI5"     => q('@15C'),
	    "HDMI6"     => q('@11D'),
            "COAX"      => q('@117'),
            "OPTICAL"   => q('@15E'),
            "ANALOG1"   => q('@15F'),
            "ANALOG2"   => q('@15G'),
            "BT"        => q('@15H'),
           },
"mode" => {
	   "STEREO" => q('@11E'),
	   "DIRECT" => q('@13J'),    
	  }, 
"mute" => {
	"on"	    => q('@11Q'),
        "off"	    => q('@11R'),
	  },
"power" => {
        "on"        => q('@112'),
        "off"       => q('@113'),
       },
"volume" => {
        "up"        => q('@11S'),
        "down"      => q('@11T'),
        "direct"    => q('@11P'),
       }
);

# called upon loading the module IOTAVX
sub IOTAVX_Initialize($)
{
  my ($hash) = @_;

  Log 5, "IOTAVX_Initialize: Entering";
		
  require "$attr{global}{modpath}/FHEM/DevIo.pm";
  
  $hash->{DefFn}    = "IOTAVX_Define";
  $hash->{UndefFn}  = "IOTAVX_Undef";
  $hash->{SetFn}    = "IOTAVX_Set";
  $hash->{ReadFn}   = "IOTAVX_Read";
  $hash->{ReadyFn}  = "IOTAVX_Ready";
}

# called when a new definition is created (by hand or from configuration read on FHEM startup)
sub IOTAVX_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t]+", $def);

  my $name = $a[0];
  
  # $a[1] is always equals the module name "IOTAVX"
  
  # first argument is a serial device (e.g. "/dev/ttyUSB0@9600")
  my $dev = $a[2]; 

  return "no device given" unless($dev);
  
  # close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  

  # add a default baud rate (9600), if not given by user
  $dev .= '@9600' if(not $dev =~ m/\@\d+$/);
  
  # set the device to open
  $hash->{DeviceName} = $dev;
  
  # open connection with custom init function
  my $ret = DevIo_OpenDev($hash, 0, "IOTAVX_Init"); 
 
  return undef;
}

# called when definition is undefined 
# (config reload, shutdown or delete of definition)
sub IOTAVX_Undef($$)
{
  my ($hash, $name) = @_;
 
  # close the connection 
  DevIo_CloseDev($hash);
  
  return undef;
}

# called repeatedly if device disappeared
sub IOTAVX_Ready($)
{
  my ($hash) = @_;
  
  # try to reopen the connection in case the connection is lost
  return DevIo_OpenDev($hash, 1, "IOTAVX_Init"); 
}

# called when data was received
sub IOTAVX_Read($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  
  # read the available data
  my $buf = DevIo_SimpleRead($hash);
  
  # stop processing if no data is available (device disconnected)
  return if(!defined($buf));
  
  Log3 $name, 5, "IOTAVX ($name) - received: $buf"; 
  
  #
  # do something with $buf, e.g. generate readings, send answers via DevIo_SimpleWrite(), ...
  #
   
}

# called if set command is executed
sub IOTAVX_Set($$@)
{
     my ($hash, @a) = @_;

    my $what = $a[1];
    my $usage = "Unknown argument $what, choose one of statusRequest";

    foreach my $cmd (sort keys %IOTAVX_set)
    {
       $usage .= " $cmd:".join(",", sort keys %{$IOTAVX_set{$cmd}});
    }

    if($what eq "statusRequest")
    {
        IOTAVX_GetStatus($hash, 1);
    }
    elsif(exists($IOTAVX_set{$what}) and exists($IOTAVX_set{$what}{$a[2]}))
    {
        DevIo_SimpleWrite($hash, $IOTAVX_set{$what}{$a[2]}."\n", 0);
    }
    else
    {
      return $usage;
    }

}
    
# will be executed upon successful connection establishment (see DevIo_OpenDev())
sub IOTAVX_Init($)
{
    my ($hash) = @_;

    # send a status request to the device
    DevIo_SimpleWrite($hash, "get_status\r\n", 2);
    
    return undef; 
}

1;