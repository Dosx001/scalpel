interface Message {
  type: string;
  payload: any;
}

let ws: WebSocket;

function init() {
  ws = new WebSocket("ws://localhost:8080");
  ws.onopen = () => {
    console.log("ws open");
  };
  ws.onclose = () => {
    console.log("ws close");
  };
  ws.onmessage = (ev) => {
    const data = JSON.parse(ev.data) as Message;
    switch (data.type) {
      case "ping":
        ws.send("pong");
        break;
      case "window":
        browser.windows.create({
          url: data.payload,
          focused: true,
        });
        break;
    }
  };
}

init();

browser.runtime.onSuspend.addListener(() => {
  ws.close();
});
