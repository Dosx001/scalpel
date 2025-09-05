let ws: WebSocket;

function init() {
  ws = new WebSocket("ws://localhost:8080");
  ws.onclose = () => {
    setTimeout(init, 1000);
  };
  ws.onmessage = (ev) => {
    const data = JSON.parse(ev.data) as Message;
    switch (data.type) {
      case "ping":
        ws.send("pong");
        break;
      case "click":
        browser.tabs.executeScript({
          code: `document.querySelector("${data.payload.query}")?.click()`,
        });
        break;
      case "text":
        browser.tabs.executeScript({
          code: `{const e=document.querySelector("${data.payload.query}");if(e)browser.runtime.sendMessage({type:"text",payload:e.innerText})}`,
        });
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

browser.runtime.onMessage.addListener((message) => {
  ws.send(JSON.stringify(message));
});
