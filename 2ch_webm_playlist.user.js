// ==UserScript==
// @name        2ch webm playlist
// @namespace   https://*2ch.hk/*
// @description Adds playlist to webm
// @include     https://2ch.hk/*
// @version        0.0000001
// @updateURL      https://raw.githubusercontent.com/anonymous2ch/2ch-webm-resizer/master/2ch_webm_playlist.user.js
// ==/UserScript==





jQuery.cachedScript = function( url, options ) {

  // Allow user to set any option except for dataType, cache, and url
  options = $.extend( options || {}, {
    dataType: "script",
    cache: true,
    url: url
  });

  // Use $.ajax() since it is more flexible than $.getScript
  // Return the jqXHR object so we can chain callbacks
  return jQuery.ajax( options );
};



 function load_player_form_webms(counter,num, src, thumb_src, n_w, n_h, o_w, o_h, minimize) {

    var win = $(window);

    /*******/
      var element = $('#exlink-' + num).closest('.images');
    if(element.length) {
        if(element.hasClass('images-single')) {
            element.removeClass('images-single');
            element.addClass('images-single-exp');
        }else if(element.hasClass('images-single-exp')) {
            element.addClass('images-single');
            element.removeClass('images-single-exp');
        }
    }
    /*******/

    if(n_w>screen.width)
    {
        n_h=((screen.width-80)*n_h)/n_w;
        n_w=screen.width-80;
    }
    var filetag, parts, ext;
    parts = src.split("/").pop().split(".");
    ext = (parts).length > 1 ? parts.pop() : "";

    if (ext == 'webm') {
    	        	abortWebmDownload();
		//$id('close-webm-' + num).style.display = "inline";
		closeWebm = $new('a',
		{
			'href': src,
			'id': 'close-webm-' + num,
			'class': 'close-webm',
			'html': '[Закрыть]',
			'onclick': ' return expand(\'' + num + "\','" + src + "','" + thumb_src + "'," + o_w + ',' + o_h + ',' + n_w + ',' + n_h + ', 1);'
		});

		//var closeWebm = document.createElement('span');
  		//closeWebm.innerHTML = '<a href="' + src + '" name="expandfunc" style="display:none" onClick="return expand(\'' + num + "\','" + src + "','" + thumb_src + "'," + o_w + ',' + o_h + ',' + n_w + ',' + n_h + ', 1);" class="close-webm">[Закрыть]</a>';;
		refElem = $id('webm-icon-' + num);
		refElem.parentNode.insertBefore(closeWebm, refElem.nextSibling);

        filetag = '<div class="video-container"><video preload="none" data-videoid="'+counter+'" id="player'+ counter+'" controls="controls" name="media"><source src="' + src + '" type="video/webm" width="200" class="video" ></video></div>';
    }
    $id('exlink-' + num).innerHTML = filetag;

    return false;
}



	$('head').append( $('<link rel="stylesheet" type="text/css" />').attr('href', 'https://img.luvka.ru/playlist/src/css/mediaelementplayer.css') );

	$('head').append( $('<link rel="stylesheet" type="text/css" />').attr('href', 'https://img.luvka.ru/playlist/src/css/mejs-skins.css') );


function appendMediaEvents($node, media) {
	var
		mediaEventNames = 'loadstart progress suspend abort error emptied stalled play pause loadedmetadata loadeddata waiting playing canplay canplaythrough seeking seeked timeupdate ended ratechange durationchange volumechange'.split(' ');
		mediaEventTable = $('<table class="media-events"><caption>Media Events</caption><tbody></tbody></table>').appendTo($node).find('tbody'),
		tr = null,
		th = null,
		td = null,
		eventName = null,
		il = 0,
		i=0;

	for (il = mediaEventNames.length;i<il;i++) {
		eventName = mediaEventNames[i];
		th = $('<th>' + eventName + '</th>');
		td = $('<td id="e_' + media.id + '_' + eventName + '" class="not-fired">0</td>');

		if (tr == null)
			tr = $("<tr/>");

		tr.append(th);
		tr.append(td);

		if ((i+1) % 5 == 0) {
			mediaEventTable.append(tr);
			tr = null;
		}

		// listen for event
		media.addEventListener(eventName, function(e) {

			var notice = $('#e_' + media.id + '_' + e.type),
				number = parseInt(notice.html(), 10);

			notice
				.html(number+1)
				.attr('class','fired');
		}, true);
	}

	mediaEventTable.append(tr);
}

function appendMediaProperties($node, media) {
	var /* src currentSrc  */
		mediaPropertyNames = 'error currentSrc networkState preload buffered bufferedBytes bufferedTime readyState seeking currentTime initialTime duration startOffsetTime paused defaultPlaybackRate playbackRate played seekabl ontrols volume'.split(' '),
		mediaPropertyTable = $('<table class="media-properties"><caption>Media Properties</caption><tbody></tbody></table>').appendTo($node).find('tbody'),
		tr = null,
		th = null,
		td = null,
		propName = null,
		il = 0,
		i=0;

	for (il = mediaPropertyNames.length; i<il; i++) {
		propName = mediaPropertyNames[i];
		th = $('<th>' + propName + '</th>');
		td = $('<td id="p_' + media.id + '_' + propName + '" class=""></td>');

		if (tr == null)
			tr = $("<tr/>");

		tr.append(th);
		tr.append(td);

		if ((i+1) % 3 == 0) {
			mediaPropertyTable.append(tr);
			tr = null;
		}
	}

	setInterval(function() {
		var
			propName = '',
			val = null,
			td = null;

		for (i = 0, il = mediaPropertyNames.length; i<il; i++) {
			propName = mediaPropertyNames[i];
			td = $('#p_' + media.id + '_' + propName);
			val = media[propName];
			val =
				(typeof val == 'undefined') ?
				'undefined' : (val == null) ? 'null' : val.toString();
			td.html(val);
		}
	}, 500);

}


function startplayer(playernum){
		 var player = new MediaElementPlayer('#player'+playernum,{

		pluginPath:'https://img.luvka.ru/playlist/build/',
		enablePluginSmoothing:true,

        loop: false,
        shuffle: false,
        playlist: false,
        audioHeight: 30,
        mode: 'native',

        playlistposition: 'bottom',
        features: [ 'shuffle','prevtrack', 'seekable', 'controls', 'playpause', 'nexttrack',  'shuffle', 'playlist', 'current', 'progress', 'duration', 'volume'],
         alwaysShowControls: true,

    iPadUseNativeControls: true,
    // force iPhone's native controls
    iPhoneUseNativeControls: true,
    // force Android's native controls
    AndroidUseNativeControls: true,
    // forces the hour marker (##:00:00)
    alwaysShowHours: true,
    // show framecount in timecode (##:00:00:00)
    pauseOtherPlayers: true,
        		success: function(me,node) {
        			me.play();
        					//mode: 'shim',
var playernext= $(node).attr('data-videoid');
var playercurrent = playernext;
playernext++;
			// report type
			var tagName = node.tagName.toLowerCase();
			$('#' + tagName + '-mode').html( me.pluginType  + ': success' + ', touch: ' + mejs.MediaFeatures.hasTouch);


			if (tagName == 'audio') {

				me.addEventListener('progress',function(e) {

				}, false);

			}

               me.addEventListener('ended', function (e) {

me.stop();
me.remove();

startplayer(playernext);



                }, false)	;


		}

    });
}

$("body").on('click','.video-container',function(event){
		event.preventDefault();

		startplayer($(this).find('video').data('videoid'));
	});
$(document).ready(function() {

$('audio, video').bind('error', function(e) {

	console.log('error',this, e, this.src, this.error.code);
});
	var count = $(".webm-file").length;


	$(".webm-file").each(function(index){

			eval( $(this).parent().attr("onclick").replace("return expand(", "load_player_form_webms("+(index+1)+",")  );

});



	$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-namespace.js").done(function( script ) {
		$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-utility.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-i18n.js");
		$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-plugindetector.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-featuredetection.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-mediaelements.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/me-shim.js");
		$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-library.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-player.js").done(function( script ) {

	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-playpause.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-progress.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-time.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-speed.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-tracks.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-volume.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-stop.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-fullscreen.js");
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/mep-feature-playlist.js").done(function( script ) {
	$.cachedScript( "https://img.luvka.ru/playlist/src/js/jquery-reverse-order.js");
startplayer(1);

	});

	});

	});





});


