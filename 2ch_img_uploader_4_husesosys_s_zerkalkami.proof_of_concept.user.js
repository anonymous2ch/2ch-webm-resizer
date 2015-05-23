// ==UserScript==
// @name           Photo uploader
// @description    Добавляет чудо-кнопку
// @author         Anonymous
// @license        LOLWUT?
// @version        0.0000002
// @include        https://2ch.hk/p/*
// @updateURL      https://raw.githubusercontent.com/anonymous2ch/2ch-webm-resizer/master/2ch_img_uploader_4_husesosys_s_zerkalkami.proof_of_concept.user.js
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

$('.de-btn-rep').click (function(event){
	window.ournum=$( event.target ).closest('div.post').data('num');

});

$('.posttime-reflink').click (function(event){
	window.ournum=$( event.target ).closest('div.post').data('num');

});


 var $fuckingbutton= '<div class="send_status" style="background-color:red;"><input id="fileupload" type="file" name="files">Файлы отправляются ПРИ ВЫБОРЕ</div>';
$('form#postform').prepend($fuckingbutton);


$('#fileupload').on('change',function(){

     var url = "https://img.luvka.ru/upload/"+window.ournum+"/";
     var file = $('#fileupload').get(0).files[0];

     $.ajax({
        url: url,
        type: "post",
        data: file,
        processData: false,
        contentType: false,
        success: function(){
        	 $(".send_status").css('background-color','green');

 $(".send_status").html('Отправка удалась!');
        },
        error:function(){
          $(".send_status").html('Ошибка');
        }
    });
  });
}


}
	);
