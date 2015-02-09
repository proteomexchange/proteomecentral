function toggle_more(id,toid,tag1, tag2){
  clearTextBox();
        var list1 = document.getElementById(tag1);
        list1.style.display = '';
  var list2 = document.getElementById(tag2);
  list2.style.display = 'none';
        var x = document.getElementById(id);
        var y = document.getElementById(toid);
        x.style.display='none';
        y.style.display='';
}
function toggle_less(id,toid,tag1,tag2){
  clearTextBox();
        var list1 = document.getElementById(tag1);
        list1.style.display = 'none';
  var list2 = document.getElementById(tag2);
  list2.style.display = '';
        var x = document.getElementById(id);
        var y = document.getElementById(toid);
        x.style.display='none';
        y.style.display='';
}

function toggle(id,toid,tag){
  var list = document.getElementById(tag);
  var x = document.getElementById(id);
  var y = document.getElementById(toid);
  if (id == 'less'){
    list.style.display = '';
  }else{
    list.style.display = 'none';
  }
  x.style.display='none';
	y.style.display='';
}


function clearTextBox(){
  var list = document.getElementsByTagName("input");
  for (var i=0; i<list.length; i++){
     if(list[i].type == 'text'){
        list[i].value = '';
     }
  }
  document.getElementById("error").innerHTML = '';
}

function configureDropDownList (opt1, opt2){
  var val = opt1.value;
  var selectedobj = document.getElementById(opt2);
  for (var i=0; i<selectedobj.length; i++){
    if (selectedobj.options[i].value == "less"
        || selectedobj.options[i].value == "greater"){
       if (val.match(/date/i)){
         selectedobj.options[i].disabled = false;
       }else{
         selectedobj.options[i].disabled = true;
       }
     }
  }
}

