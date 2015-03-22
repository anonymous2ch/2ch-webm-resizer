#!/usr/bin/perl -w
use strict;
use warnings;
use POSIX;
use IPC::Open3;
use File::stat;
use Getopt::Long qw(:config pass_through);
use Pod::Usage;
use File::Basename;
use DirHandle;

$SIG{INT}  = sub { die "Caught a sigint $!" };
$SIG{TERM} = sub { die "Caught a sigterm $!" };

my $man  = 0;
my $help = 0;
my $additional_filename_num;
my $stop_processing;
my $frames_to_encode;
my $frames_to_skip;
my $seconds_to_skip;
my $finalsize;
my $target_size;
my $target_frame_rate;
my $no_third_step;
my $no_resize = 0;
my $filename;
my $filename_without_extension;
my $path;
my $extension;

my $encoded_video_size;
my $time_start;
my $time_finish;
my $cpu_used;
my $deadline;

our $ffmpeg_debug_params;

# Function definition

my $max_temp_frames;
my $temp_size;
my $accepted_percent_change;
my $temp_slices;
my $concat_string = '';
my $force_width;
my $no_audio;
my $audiotrack;
my $opus_cut;
my $total_slices;
my $sem;
my @thr;
our %filenames;
our %sizes;
our %timing;
our %encoding_params;
my $ffmpeg_params;
our $ffmpeg_binary   = "ffmpeg";
our $ffprobe_binary  = "ffprobe";
our $mkvmerge_binary = "mkvmerge";
our %videoInfo;

$time_start = time;

GetOptions( 'help|?' => \$help, man => \$man ) or pod2usage(2);

pod2usage(1) if $help;

pod2usage( -exitval => 0, -verbose => 2 ) if $man;

pod2usage("$0: No files given.") if ( ( @ARGV == 0 ) && ( -t STDIN ) );

GetOptions( "ss=s" => \$timing{"start_from"},
    "to=s"                      => \$timing{"end_to"},
    "target=n"                  => \$sizes{"target_video_size"},
    "max_temp_frames=n"         => \$max_temp_frames,
    "temp_slices=n"             => \$temp_slices,
    "temp_size=n"               => \$temp_size,
    "accepted_percent_change=n" => \$accepted_percent_change,
    "opus=n"                    => \$encoding_params{"opus_bitrate"},
    "no_resize"                 => \$no_resize,
    "threads=n"                 => \$encoding_params{"threads"},
    "qmin=n"                    => \$encoding_params{"qmin"},
    "crf=n"                     => \$encoding_params{"crf"},
    "qmax=n"                    => \$encoding_params{"qmax"},
    "aq_mode=n"                 => \$encoding_params{"aq_mode"},
    "width=n"                   => \$force_width,
    "cpu_used=n"                => \$encoding_params{"cpu_used"},
    "deadline=s"                => \$deadline,
    "ffmpeg_params=s"           => \$ffmpeg_params,
    "quality=s"                 => \$encoding_params{"quality"},
    "no_audio"                  => \$no_audio,
    "audio=s"                   => \$audiotrack,
    "verbose"                   => \$encoding_params{"verbose"},
);

$force_width //= -1;
print $time_start;
$opus_cut //= '';

#params//="-static-thresh 0 -arnr-maxframes 7 -arnr-strength 5";
$ffmpeg_params //= "";

print "\n-------------------------------START---------------------------------------\n";
print "\nStarted: " . strftime( "%Y-%m-%d %H:%M:%S", localtime($time_start) ) . "\n\n";

$no_resize                       //= 1;
$encoding_params{"threads"}      //= 8;
$temp_slices                     //= 8;
$max_temp_frames                 //= 800;
$temp_size                       //= 25;
$encoding_params{"opus_bitrate"} //= 70;
$encoding_params{"qmin"}         //= 8;
$encoding_params{"qmax"}         //= 60;
$encoding_params{"crf"}          //= 15;
$encoding_params{"cpu_used"}     //= 1;
$no_audio                        //= 0;
$deadline                        //= "1000000";
$no_resize = 1;

$sizes{"target_video_size"} //= 6144;
$accepted_percent_change    //= 13;
$encoding_params{"verbose"} //= '';
$encoding_params{"quality"} //= "good";
$encoding_params{"aq_mode"} //= 2;
$ffmpeg_debug_params        //= '-loglevel quiet';

if ( $encoding_params{"verbose"} ne '' )
{
    $ffmpeg_debug_params = '';
}

if ( $no_audio > 0 )
{
    $encoding_params{"opus_bitrate"} = 0;
}

if ( $force_width > 0 )
{
    $no_resize = 1;
}

if ( $encoding_params{"threads"} > $temp_slices )
{
    print "\nConsider setting -temp_slices=" . $encoding_params{"threads"} . " for optimal multithreading performance\n";
}

pod2usage("\n$0: Invalid Arguments.\n") unless ( @ARGV == 1 );

$filename = $ARGV[0];

unless ( -e $filename ) {
    die("File Doesn't Exist!\n");
}
$filenames{"filename"} = $filename;
$filenames{"filename"} =~ s/[^A-Za-z0-9\/\-_\.]//g;
if ( $filenames{"filename"} ne $filename )
{
    die("Please remove any special chars from the filename for your own good");
}

( $filenames{"filename_without_extension"}, $filenames{"path"}, $filenames{"extension"} ) = fileparse( $filename, qr/\.[^.]*/ );

if ( $filenames{"path"} eq '' )

{
    $filenames{"path"} = '.';
}

$filenames{"audiotrack_filename"} //= $filenames{"filename"};
my $audiotrack_fileclean = $filenames{"audiotrack_filename"};
$audiotrack_fileclean =~ s/[^A-Za-z0-9\/\-_\.]//g;

if ( $filenames{"audiotrack_filename"} ne $audiotrack_fileclean )
{
    die("Please remove any special chars from the audio track filename for your own good");
}
DeleteTempFiles();

%videoInfo = GetVideoInfo( $filenames{"filename"} );
my $pre_init_cut = '';
my ( $hours, $minutes, $seconds );

if ( $timing{"start_from"} )
{
    if ( $timing{"start_from"} !~ /^(([0-9]?[0-9]):([[0-5]?[0-9]):([0-5]?[0-9])(.([0-9]([0-9]?[0-9]?)?))?)$/ ) { pod2usage( "$0: Wrong time format for -ss argument (" . $timing{"start_from"} . ").\n" ) }

    ( $hours, $minutes, $seconds ) = split( /[:]/, $timing{"start_from"} );
    if ( ( ( $hours * 3600 ) + ( $minutes * 60 ) + $seconds ) > $videoInfo{'durationsecs'} ) { die( "Start time -ss " . $timing{"start_from"} . " is invalid, source video size is just $videoInfo{'duration'}\n" ); }
    $timing{"start_from"} = ( ( $hours * 3600 ) + ( $minutes * 60 ) + $seconds );
    $pre_init_cut = 'true';
}

$hours   = 0;
$minutes = 0;
$seconds = 0;

if ( $timing{"end_to"} )
{

    if ( $timing{"end_to"} !~ /^(([0-9]?[0-9]):([[0-5]?[0-9]):([0-5]?[0-9])(.([0-9]([0-9]?[0-9]?)?))?)$/ ) { pod2usage( "$0: Wrong time format for -to argument (" . $timing{"end_to"} . ").\n" ) }

    ( $hours, $minutes, $seconds ) = split( /[:]/, $timing{"end_to"} );

    $timing{"end_to"} = ( ( $hours * 3600 ) + ( $minutes * 60 ) + $seconds );

    $pre_init_cut = 'true';
}

if ( !( $pre_init_cut eq '' ) )
{

    PrecutVideo();

    %videoInfo = GetVideoInfo( $filenames{"filename"} );
}

CalculateSizes( $main::filenames{"filename"} );

$additional_filename_num = "-bitrate". $main::sizes{"target_bitrate"} . "-opus" . $encoding_params{"opus_bitrate"} . "-" . strftime( "%Y%m%d-%H%M%S", localtime );

SliceVideoByThreads();
EncodeVideo();
MergeSlices();

EncodeAudio();

# returns media information in a hash

system("stty sane");
$time_finish = time;

print "\n\nFinished: " . strftime( "%Y-%m-%d %H:%M:%S", localtime($time_finish) ) . "\n";
print "-------------------------------FINISHED---------------------------------------\n";
print "Total encoding time: " . ( $time_finish - $time_start ) . " seconds\n";
DeleteTempFiles();

sub percent_change {
    my ( $from, $to ) = @_;
    return unless $from;
    return if int($from) == 0;

    if ( $from == 0 && $to == 0 ) {
        return 0;
    }
    my $diff = ( ( $to - $from ) / abs($from) ) * 100;
    return $diff;
}

sub GetVideoInfo {

    my %finfo = (
        'duration'     => "00:00:00.00",
        'durationsecs' => "0",
        'bitrate'      => "0",
        'vcodec'       => "",
        'vformat'      => "",
        'acodec'       => "",
        'asamplerate'  => "0",
        'achannels'    => "0",
    );

    my $file = shift;

    # escaping characters
    $file =~ s/(\W)/\\$1/g;

    open3( "</dev/null", \*ERPH, \*ERPH, $main::ffprobe_binary . " -select_streams v -show_format -show_streams -hide_banner  $file" ) or die "can't run $main::ffprobe_binary\n";
    my @res = <ERPH>;

    # parse ffmpeg output
    foreach (@res) {
        if (m!Duration: ([0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9])!) {
            $finfo{'duration'} = $1;
        }

        if (m!width=(\d*)!) {
            $finfo{'width'} = $1;
        }

        if (m!height=(\d*)!) {
            $finfo{'height'} = $1;
        }

        if (m!r_frame_rate=(\d*/\d*)!) {
            my $framerate_float = eval $1;
            $finfo{'frame_rate'} = sprintf( "%.2f", $framerate_float );

        }

        if (m!size=(\d*)!) {
            $finfo{'size'} = $1;
        }

        # duration
        if (m!Duration: ([0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9])!) {
            $finfo{'duration'} = $1;
        }

        # bitrate
        if (m!bitrate: (\d*) kb/s!) {
            $finfo{'bitrate'} = $1;
        }

        # vcodec and vformat
        if (/Video: (\w*), (\w*),/) {
            $finfo{'vcodec'}  = $1;
            $finfo{'vformat'} = $2;

        }

        if (m!nb_frames=(\d*)!) {
            $finfo{'nb_frames'} = $1;

        }

        # Stream #0.1(und): Audio: aac, 48000 Hz, 1 channels, s16, 64 kb/s

        # acodec, samplerate, stereo and audiorate
        if (m!Audio: (\w*), (\d*) Hz, (\d*)!) {
            $finfo{'acodec'}      = $1;
            $finfo{'asamplerate'} = $2;
            $finfo{'achannels'}   = $3;
        }
    }

    my $tenths  = substr( $finfo{'duration'}, 9, 2 );
    my $seconds = substr( $finfo{'duration'}, 6, 2 );
    my $minutes = substr( $finfo{'duration'}, 3, 2 );
    my $hours   = substr( $finfo{'duration'}, 0, 2 );
    $finfo{'durationsecs'} = ( $tenths * .01 ) + $seconds + ( $minutes * 60 ) + ( $hours * 360 );
    if ( $finfo{'nb_frames'} eq "N/A" )
    {
        $finfo{'nb_frames'} = $finfo{'durationsecs'} * $finfo{'frame_rate'};
    }

    if ( $finfo{'nb_frames'} eq "" )
    {
        $finfo{'nb_frames'} = $finfo{'durationsecs'} * $finfo{'frame_rate'};
    }

    return %finfo;
}

sub PrecutVideo {

    my $keyframe_data;
    my $end_keyframe_time;
    my $start_keyframe_time;

    print "Cutting work area from video " . $main::filenames{"filename"} . " by keyframes with parameters " . $main::timing{"start_from"} . " " . $main::timing{"end_to"} . "\n\n";

    $start_keyframe_time = `ffprobe -show_frames -select_streams v:0 -print_format csv $main::filenames{"filename"} | grep -B 1 'frame,video,1' | grep 'frame,video,0' | awk -F ',' '\$5 < $main::timing{start_from}' | tail -n 1 | awk -F ',' '{printf \$5}'`;

    $end_keyframe_time = `ffprobe -show_frames -select_streams v:0 -print_format csv $main::filenames{"filename"} | grep -B 1 'frame,video,1' | grep 'frame,video,0' | awk -F ',' '\$5 > $main::timing{end_to}' | head -n 1 | awk -F ',' '{printf \$5}'`;

    system( $main::ffmpeg_binary,
        "-stats",
        "-i",      $main::filenames{"filename"},
        "-ss",     $start_keyframe_time,
        "-t",      $end_keyframe_time,
        "-vcodec", "copy",
        "-hide_banner",
        "-y",
        "-acodec", "copy",
        "-async",  "1",
        $main::filenames{"filename_without_extension"} . "-temp-work" . $main::filenames{"extension"},
    );

    $main::filenames{"filename"} = $main::filenames{"filename_without_extension"} . "-temp-work" . $main::filenames{"extension"};

    print "\nDone\nWorking with " . $main::filenames{"filename"} . "\n";

}

sub CalculateSizes
{
    my $videofilename = shift(@_);
    print $videofilename;
    %main::videoInfo = GetVideoInfo($videofilename);

    $main::sizes{"target_bitrate"} = floor(( ( $main::sizes{"target_video_size"} - ( ( $main::videoInfo{"durationsecs"} * $main::encoding_params{"opus_bitrate"} ) / 8 ) ) * 8 ) / $main::videoInfo{"durationsecs"});
    print "Video Data:\n\n";
    print "duration: " . $main::videoInfo{'duration'} . "\n";
    print "durationsecs: " . $main::videoInfo{'durationsecs'} . "\n";
    print "bitrate: " . $main::videoInfo{'bitrate'} . "\n";
    print "vcodec: " . $main::videoInfo{'vcodec'} . "\n";
    print "vformat: " . $main::videoInfo{'vformat'} . "\n";
    print "acodec: " . $main::videoInfo{'acodec'} . "\n";
    print "asamplerate: " . $main::videoInfo{'asamplerate'} . "\n";
    print "achannels: " . $main::videoInfo{'achannels'} . "\n";
    print "width: " . $main::videoInfo{'width'} . "\n";
    print "height: " . $main::videoInfo{'height'} . "\n";
    print "nb_frames: " . $main::videoInfo{'nb_frames'} . "\n";
    print "size: " . $main::videoInfo{'size'} . "\n";
    print "frame_rate: " . $main::videoInfo{'frame_rate'} . "\n\n";
    print "\n\n---\nTarget Video Size with " . $main::encoding_params{"opus_bitrate"} . " Opus bitrate: " . ( $main::sizes{"target_video_size"} - ( ( $main::videoInfo{"durationsecs"} * $main::encoding_params{"opus_bitrate"} ) / 8 ) ) . "\n";
    print "Target Video Bitrate with " . $main::encoding_params{"opus_bitrate"} . " Opus bitrate: " . $main::sizes{"target_bitrate"} . "\n---\n\n";

}

sub SliceVideoByKeyFrames {

    print "\n\n---\nCreating slices from video $filenames{'filename'}\n--\n\n";

    system( $main::ffmpeg_binary,
        "-i",                $main::filenames{"filename"},
        "-acodec",           "copy",
        "-f",                "segment",
        "-vcodec",           "copy",
        "-reset_timestamps", "1",
        "-map",              "0",
        "-async",            "1",
        $main::filenames{"filename_without_extension"} . "-temp-source-slice-%03d" . $main::filenames{"extension"} );

    my $file;

    my $dh = DirHandle->new( $main::filenames{"path"} ) or die "Can't open " . $main::filenames{"path"} . " : $!\n";

    my @slices = grep( /$filenames{"filename_without_extension"}-temp-source-slice-[0-9]*$main::filenames{"extension"}$/, $dh->read() );

    $main::filenames{"total_slices"} = scalar @slices;
    $main::filenames{"slices"}       = @slices;

}

sub SliceVideoByThreads
{
    $main::sizes{"slice_duration_sec"} = ceil( $main::videoInfo{durationsecs} / $main::encoding_params{"threads"} );
    print "ffprobe -show_frames -select_streams v:0 -print_format csv $main::filenames{filename}  2>&1 | grep -n frame,video,1 | awk 'BEGIN { FS=\",\" } { print \$1 \" \" \$5 }' | sed 's/:frame//g' | awk 'BEGIN { previous=0; frameIdx=0; size=0; } { split(\$2,time,\"\.\"); current=time[1]; if (current-previous >= $main::sizes{slice_duration_sec} ){ a[frameIdx]=\$1; frameIdx++; size++; previous=current;} } END { str=a[0]; for(i=1;i<size;i++) { str = str \",\" a[i]; } print str;}' | tr -d '\n'";

    my $threaded_key_frames = `ffprobe -show_frames -select_streams v:0 -print_format csv $main::filenames{filename}  2>&1 | grep -n frame,video,1 | awk 'BEGIN { FS="," } { print \$1 " " \$5 }' | sed 's/:frame//g' | awk 'BEGIN { previous=0; frameIdx=0; size=0; } { split(\$2,time,"\."); current=time[1]; if (current-previous >= $main::sizes{slice_duration_sec}){ a[frameIdx]=\$1; frameIdx++; size++; previous=current;} } END { str=a[0]; for(i=1;i<size;i++) { str = str "," a[i]; } print str;}' | tr -d '\n'`;

    my @keyframes = split( ',', $threaded_key_frames );
    $threaded_key_frames = join( ',', @keyframes );

    print "\n\n$threaded_key_frames";
    system( $main::ffmpeg_binary,
        '-i',
        $main::filenames{'filename'},
        '-vcodec',
        'copy',
        '-map', '0',
        '-an',
        '-y',
        '-f',              'segment',
        '-segment_frames', $threaded_key_frames,
        $main::filenames{'filename_without_extension'} . "-temp-work-slice%03d" . $main::filenames{'extension'},
    );

    my $dh = DirHandle->new( $main::filenames{"path"} ) or die "Can't open " . $main::filenames{"path"} . " : $!\n";

    my @work_slices = grep( /$main::filenames{filename_without_extension}-temp-work-slice[0-9]*$main::filenames{extension}$/, $dh->read() );

    $main::filenames{"work_slices"} = @work_slices;

    $main::sizes{"total_work_slices"} = scalar @work_slices;

}

sub EncodeVideo
{
    my $padded;

    print "\n\n\n\n------------------------FFMPEG PARAMS-----------------------------------\n";
    print "\nStarted: " . strftime( "%Y-%m-%d %H:%M:%S", localtime($time_start) ) . "\n\n";
    print("Encoding with the following params:\n");
    print join( " ", (
            '-stats',
            '-hide_banner',
            '-cpu-used', $main::encoding_params{"cpu_used"},
            '-aq-mode',  $main::encoding_params{"aq_mode"},
            '-c:v',      'libvpx-vp9',
            '-y',
            '-an',
            '-b:v',           $main::sizes{"target_bitrate"} . "k",
            '-strict',        '-2',
            '-quality',       $main::encoding_params{"quality"},
            '-qmin',          $main::encoding_params{'qmin'},
            '-crf',           $main::encoding_params{'crf'},
            '-qmax',          $main::encoding_params{'qmax'},
            '-vf',            'scale=' . $force_width . ':-1',
            '-sws_flags',     'spline',
            '-lag-in-frames', '16',
            '-pass',          '1',
            '-f',             'webm',
    ) );
    print "\n-----------------------------------------------------------------------\n\n\n\n";

    for ( my $i = 0 ; $i < $main::sizes{"total_work_slices"} ; $i++ ) {

        my $pid = fork();
        if ( $pid == 0 ) {

            $padded = sprintf "%03d", $i;
            exec( $main::ffmpeg_binary,
                '-stats',
                '-i', $main::filenames{'filename_without_extension'} . "-temp-work-slice" . $padded . $main::filenames{'extension'},
                '-hide_banner',
                '-cpu-used',    $main::encoding_params{"cpu_used"},
                '-passlogfile', $main::filenames{filename_without_extension} . '-temp-work-passlog' . $padded,
                '-aq-mode',     $main::encoding_params{"aq_mode"},
                '-c:v',         'libvpx-vp9',
                '-y',
                '-an',
                '-b:v',           $main::sizes{"target_bitrate"} . "k",
                '-strict',        '-2',
                '-quality',       $main::encoding_params{"quality"},
                '-qmin',          $main::encoding_params{'qmin'},
                '-crf',           $main::encoding_params{'crf'},
                '-qmax',          $main::encoding_params{'qmax'},
                '-vf',            'scale=' . $force_width . ':-1',
                '-sws_flags',     'spline',
                '-lag-in-frames', '16',
                '-pass',          '1',
                '-f',             'webm',
                '/dev/null' );
        }
        elsif ( !defined $pid ) {
            warn "Fork $i failed: $!\n";
        }
    }

    1 while wait() >= 0;

    for ( my $i = 0 ; $i <= $main::sizes{"total_work_slices"} ; $i++ ) {



        my $pid = fork();
        if ( $pid == 0 ) {

            $padded = sprintf "%03d", $i;
            exec( $main::ffmpeg_binary,
                '-stats',
                '-i', $main::filenames{'filename_without_extension'} . "-temp-work-slice" . $padded . $main::filenames{'extension'},
                '-hide_banner',
                '-cpu-used',    $main::encoding_params{"cpu_used"},
                '-passlogfile', $main::filenames{filename_without_extension} . '-temp-work-passlog' . $padded,
                '-aq-mode',     $main::encoding_params{"aq_mode"},
                '-c:v',         'libvpx-vp9',
                '-y',
                '-an',
                '-b:v',           $main::sizes{"target_bitrate"} . "k",
                '-strict',        '-2',
                '-quality',       $main::encoding_params{"quality"},
                '-qmin',          $main::encoding_params{'qmin'},
                '-crf',           $main::encoding_params{'crf'},
                '-qmax',          $main::encoding_params{'qmax'},
                '-vf',            'scale=' . $force_width . ':-1',
                '-sws_flags',     'spline',
                '-lag-in-frames', '16',
                '-pass',          '2',
                '-auto-alt-ref',  '1',
                $main::filenames{"filename_without_extension"} . "-temp-noresize-slice-" .  $padded . ".webm" );

        }
        elsif ( !defined $pid ) {
            warn "Fork $i failed: $!\n";
        }

    }

    1 while wait() >= 0;

}

sub MergeSlices
{
    my $file;
    my $concat_string = '';
    my $i             = 0;
    my $dh            = DirHandle->new( $main::filenames{"path"} ) or die "Can't open " . $main::filenames{"path"} . " : $!\n";
    my @files         = grep( /$main::filenames{"filename_without_extension"}-temp-noresize-slice-.*$/, $dh->read() );
    my $padded;

    foreach $file (@files) {
    	  $padded = sprintf "%03d", $i;
        $concat_string = $concat_string . " " . $main::filenames{"filename_without_extension"} . "-temp-noresize-slice-" .  $padded . ".webm +";
        $i++;
    }
    print $concat_string;
    system( "mkvmerge -q -o " . $main::filenames{"filename_without_extension"} . "-temp-result-webm.webm $concat_string" );

}

sub DeleteTempFiles {
    my $file;

    my $dh = DirHandle->new( $main::filenames{"path"} ) or die "Can't open $path : $!\n";
    my @files = grep( /$filenames{"filename_without_extension"}-temp-.*$/, $dh->read() );

    foreach $file (@files) {
        unlink $main::filenames{"path"} . $file or warn "Could not delete temporary $file: $!";
    }
    DeletePassLogs();
}

sub DeletePassLogs {

    my $file;

    my $dh = DirHandle->new( $main::filenames{"path"} ) or die "Can't open $path : $!\n";
    my @files = grep( /$filenames{"filename_without_extension"}.*\.log$/, $dh->read() );

    foreach $file (@files) {
        unlink $main::filenames{"path"} . $file or warn "Could not delete log $file: $!";
    }
}

sub CalculateAudioBitrate {

    my $result_webm_filename = $main::filenames{"filename_without_extension"} . "-temp-result-webm.webm";

    my $st = stat($result_webm_filename);

    my $webm_size = $st->size;

    return floor( ( ( ( $main::sizes{"target_video_size"} * 1024 ) - $webm_size ) * 8 ) / $main::videoInfo{'durationsecs'} );

}

sub EncodeAudio {

    my $multiplier = shift(@_);
    $multiplier //= 1;
    my $audio_filename = $main::filenames{"audiotrack_filename"};

    print "Encoding audio with " . floor( CalculateAudioBitrate() * $multiplier ) . " bitrate:\n";

    system( "ffmpeg -v quiet -stats -i " . $main::filenames{"audiotrack_filename"} . " -c:a libopus  -b:a " . floor( CalculateAudioBitrate() * $multiplier ) . " -vbr on -vn -sn -y -hide_banner " . $main::filenames{"filename_without_extension"} . "-temp-result-opus.mkv" );
    print "Muxing:\n";
    system( "mkvmerge -q -A " . $main::filenames{"filename_without_extension"} . "-temp-result-webm.webm " . $main::filenames{"filename_without_extension"} . "-temp-result-opus.mkv -o " . $main::filenames{"filename_without_extension"} . "-result" . $additional_filename_num . ".webm" );
    my $finalsize = ceil( ( stat( $main::filenames{"filename_without_extension"} . "-result" . $additional_filename_num . ".webm" )->size ) / 1024 );
    print "\n\n\n--------\n";
    print "Final Video + Audio Size is $finalsize KB\n";

    if ( $finalsize > $main::sizes{"target_video_size"} )

    {
        print "Final sizing failed\n";
        EncodeAudio( $multiplier * ( ( $main::sizes{"target_video_size"} / $finalsize ) * 0.99 ) );
    }

}
__END__
=encoding utf-8
=head1 NAME

sample - Using Getopt::Long and Pod::Usage

=head1 SYNOPSIS

Multithreaded VP9 encoding

Данная версия является альфой от 22.03.2015, за обновлениями следите в https://2ch.hk/s/


2ch-webm-resizer.pl [options] [file_to_encode]

	Options:

		General:

		-width (Default: not set) force resizing to a specified width

		Size:

		-target (Default: 6144) target file size in kilobytes
		-opus (Default: 70) opus bitrate to calculate the video size from (used only for calculations)

		Quality:

		-crf (Default: 33) target quality quantizer
		-qmin (Default: 8) maximum allowed quality while encoding with crf
		-qmax (Default: 60) minimum allowed quality while encoding with crf
		-cpu_used (Default: 1) cpu_used value for encoding (-16...16)
		-quality (Default: good)
		-aq_mode (Default: 2)

		Performance:

		-threads (Default: 8) number of ffmpeg encoder threads

		Unimplemented:

		-help brief help message (not implemented)
		-man full documentation (not implemented)


=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut
