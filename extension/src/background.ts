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
        browser.windows
          .create({
            url: data.payload.url,
            focused: true,
            incognito: data.payload.private ?? false,
          })
          .then((window) => {
            ws.send(
              JSON.stringify({
                id: window.id,
                tabId: (window.tabs ?? [])[0].id,
              }),
            );
          });
        break;
    }
  };
}

init();

browser.runtime.onSuspend.addListener(() => {
  ws.close();
});
