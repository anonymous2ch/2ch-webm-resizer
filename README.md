Быдлокод неистребим, но мы скажем что это перл виноват, нечитаемый, ко-ко-ко, нутыпонял...

Multithreaded VP9 encoding

Example Usage:

./2ch-webm-resizer-test.pl -width 720 -target 6144 -opus 65 -cpu_used 0 -aq_mode 1 max100500.mp4
./2ch-webm-resizer-test.pl mayatachila.mp4

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