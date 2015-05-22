// ==UserScript==
// @name        Photo uploader
// @namespace   *2ch.hk/p/*
// @include     https://2ch.hk/p/
// @version     1
// @grant       none
// ==/UserScript==




$(document).ready(function() {

$('.post').prepend(
function()
{
	return '<img src="https://img.luvka.ru/'+$(this).data('num')+'">';

});


if ($('form#postform').length)
{


$('.postbtn-options').click(function(){
	window.ournum=$(this).data('num');

});
 var $fuckingbutton= '<div class="send_status" style="background-color:red;"><input id="fileupload" type="file" name="files">Файлы отправляются ПРИ ВЫБОРЕ</div>';
$('form#postform').prepend($fuckingbutton);


$('#fileupload').on('change',function(){

     console.log("handleFileUpload called");
     var url = "https://img.luvka.ru/upload/"+window.ournum+"/";
     var file = $('#fileupload').get(0).files[0];

     $.ajax({
        url: url,
        type: "post",
        data: file,
        processData: false,
        contentType: false,
        success: function(){
        	 $(".send_status").css('background-color','none');

 $(".send_status").html('Отправка удалась <img src="https://img.luvka.ru/'+window.ournum+'">');
        },
        error:function(){
          $(".send_status").html('there was an error while submitting');
        }
    });
  });
}


}
	);
