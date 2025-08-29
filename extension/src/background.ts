let ws: WebSocket;

function init() {
  ws = new WebSocket("ws://localhost:8080");
  ws.onopen = () => {
    console.log("ws opened");
  };
  ws.onmessage = (e) => {
    console.log(e.data);
  };
}

init();
