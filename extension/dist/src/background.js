(function(){"use strict";let o;function e(){o=new WebSocket("ws://localhost:8080"),o.onopen=()=>{console.log("ws opened")},o.onmessage=n=>{console.log(n.data)}}e()})();
