let ws: WebSocket;

function init() {
  ws = new WebSocket("ws://localhost:8080");
  ws.onclose = () => {
    setTimeout(init, 1000);
  };
  ws.onmessage = (ev) => {
    const data = JSON.parse(ev.data) as Payload;
    switch (data.type) {
      case "ping":
        ws.send("pong");
        break;
      case "click":
        browser.scripting.executeScript({
          target: { tabId: data.id },
          args: [data.query],
          func: (query: string) => {
            const el = document.querySelector<HTMLElement>(query);
            if (el) {
              el.click();
              browser.runtime.sendMessage({
                type: "click",
                payload: "clicked",
              });
            }
          },
        });
        break;
      case "text":
        browser.scripting.executeScript({
          target: { tabId: data.id },
          args: [data.query],
          func: (query: string) => {
            const el = document.querySelector<HTMLElement>(query);
            if (el)
              browser.runtime.sendMessage({
                type: "text",
                payload: el.innerText,
              });
          },
        });
        break;
      case "window":
        browser.windows
          .create({
            url: data.url,
            focused: true,
            incognito: data.private ?? false,
          })
          .then((window) => {
            const tab = (window.tabs ?? [])[0];
            if (tab)
              browser.tabs.onUpdated.addListener(handleUpdate, {
                tabId: tab.id,
                windowId: window.id,
                properties: ["status"],
              });
          });
        break;
    }
  };
}

init();

function handleUpdate(
  tabId: number,
  info: browser.tabs._OnUpdatedChangeInfo,
  tab: browser.tabs.Tab,
) {
  if (info.status === "complete") {
    ws.send(
      JSON.stringify({
        id: tab.windowId,
        tabId: tabId,
      }),
    );
    browser.tabs.onUpdated.removeListener(handleUpdate);
  }
}

browser.runtime.onSuspend.addListener(() => {
  ws.close();
});

browser.runtime.onMessage.addListener((message) => {
  ws.send(JSON.stringify(message));
});

function keepAlive() {
  browser.alarms.create({ when: Date.now() + 29_500 });
}
browser.alarms.onAlarm.addListener(keepAlive);
browser.runtime.onStartup.addListener(keepAlive);
browser.runtime.onInstalled.addListener(keepAlive);
