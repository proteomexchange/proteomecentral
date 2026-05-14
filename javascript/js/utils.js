function pc_getRecentItems(type,max=10) {
    migrate_and_deprecate_me();
    if (!localStorage["Recent_"+type])
        return [];

    var recent_items = JSON.parse(localStorage["Recent_"+type]);

    return recent_items.slice(0, max);
}

function pc_addRecentItem(type,item) {
    var recent_items = [];
    if (localStorage["Recent_"+type])
        recent_items = JSON.parse(localStorage["Recent_"+type]);

    const index = recent_items.indexOf(item);
    if (index > -1)
        recent_items.splice(index, 1);

    recent_items.unshift(item);

    localStorage.setItem("Recent_"+type, JSON.stringify(recent_items));
}

function pc_displaySpecialWarning(message=null) {
    if (!message) return;

    var div = document.createElement("div");
    div.style.fontSize =  "large";
    div.style.padding = "20px";
    div.style.background = "#ec1";
    div.append(message);

    document.body.prepend(div);
}

function pc_addCheckBox(ele,remove) {
    var check = document.createElement("span");
    check.className = 'buttonlike on';
    check.style.position = 'fixed';
    check.style.marginLeft = '10px';
    check.style.marginTop = '-5px';
    check.innerHTML = '&check;';
    ele.parentNode.insertBefore(check, ele.nextSibling);

    if (remove)
        var timeout = setTimeout(function() { check.remove(); }, 1500 );
}

// from w3schools (mostly)
function tpp_dragElement(ele) {
    ele.style.cursor = "move";
    var posx1 = 0, posx2 = 0, posy1 = 0, posy2 = 0;
    if (document.getElementById(ele.id + "header"))
        document.getElementById(ele.id + "header").onmousedown = dragMouseDown;
    else
        ele.onmousedown = dragMouseDown;

    function dragMouseDown(e) {
        e = e || window.event;
        e.preventDefault();
        posx2 = e.clientX;
        posy2 = e.clientY;
        document.onmouseup = closeDragElement;
        document.onmousemove = elementDrag;
    }

    function elementDrag(e) {
        e = e || window.event;
        e.preventDefault();
        posx1 = posx2 - e.clientX;
        posy1 = posy2 - e.clientY;
        posx2 = e.clientX;
        posy2 = e.clientY;
        ele.style.top  = (ele.offsetTop  - posy1) + "px";
        ele.style.left = (ele.offsetLeft - posx1) + "px";
        ele.style.right = 'initial';
    }

    function closeDragElement() {
        document.onmouseup = null;
        document.onmousemove = null;
    }
}

// //////////////////////////////////////
// DEPRECATE THIS soon...
function migrate_and_deprecate_me() {
    if (!localStorage.USIcount)
        return;

    var i = 0;
    while (i <= Number(localStorage.USIcount)) {
        var dausi = localStorage.getItem("USI_"+i);
        if (dausi) {
            localStorage.removeItem("USI_"+i);
	    pc_addRecentItem("USI",dausi);
	}
        i++;
    }
}
