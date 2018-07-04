onICHostReady = function(version) {

   if ( version != 1.0 ) {
      alert('Invalid API version');
   }

   gICAPI.onProperty = function(properties) {
      var ps = JSON.parse(properties);
      if (ps.url!="") {
        setTimeout( function () {
          downloadURL(ps.url);
        }, 0);
      }
   }

}

var lang
var banner_image
var loading_string
var powered_by_string

function setLocale(lang_short_code) {
  lang = lang_short_code;
  //lang = JSON.stringify(lang_short_code);
  lang = lang.toUpperCase();
  
  if (lang == "EN") {
    banner_image = "banner.png";
    loading_string = "Loading...";
    powered_by_string = "Powered by...";
  } else if (lang == "FR") {
    banner_image = "banner.png";
    loading_string = "Chargement...";
    powered_by_string = "Alimenté par...";
  }
  var link = document.createElement("link");
  link.href = "splash.css";
  link.rel="stylesheet";
  link.type="text/css";
  document.head.appendChild(link);
  document.body.innerHTML = 
  " <div style=\"display:table; height:100%; width:100%;\"> \
      <div style=\"display:table-cell;vertical-align:middle; width:100%; text-align:center;\"> \
        <div style=\"margin-left:auto;margin-right:auto;\"> \
            <img src=\"" + banner_image + "\" width=\"75%\" /><br /> \
            <h1 style=\"font-size: 200%;\">" + powered_by_string + "</h1> \
            <img src=\"genero.png\" width=\"40%\" /><br /><br /> \
            <h1 style=\"font-size: 250%;\">" + loading_string + "</h1><br /> \
            <img src=\"box.gif\" /><br /> \
        </div> \
      </div> \
    </div> \
  "
  
  return "OK";
}
