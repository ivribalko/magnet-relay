/**
 * Updates one diagnostic value and its visual state.
 */
function setDiagnostic(element, value, state = "") {
    element.textContent = value;
    if (state) {
        element.dataset.state = state;
    } else {
        delete element.dataset.state;
    }
}

/**
 * Applies connection diagnostics supplied by the native app.
 */
function showConnectionStatus(status) {
    setDiagnostic(
        document.getElementById("lan-permission"),
        status.lanPermission,
        status.lanState
    );
    document.getElementById("server-port").textContent = status.serverPort;
    setDiagnostic(
        document.getElementById("server-version"),
        status.serverVersion,
        status.serverState
    );

    const message = document.getElementById("status");
    message.textContent = status.message || "";
    message.dataset.state = status.messageState || "";

    document.getElementById("refresh-button").disabled = status.checking === true;
    document.getElementById("open-button").disabled = status.canOpen !== true;
}

/**
 * Displays the result of a magnet-link operation.
 */
function showOperationStatus(status) {
    const message = document.getElementById("operation-status");
    message.textContent = status.message || "";
    message.dataset.state = status.state || "";
    document.getElementById("refresh-button").disabled = status.busy === true;
}

function postNativeMessage(message) {
    webkit.messageHandlers.controller.postMessage(message);
}

document.getElementById("refresh-button").addEventListener("click", () => {
    postNativeMessage("refresh-status");
});

document.getElementById("open-button").addEventListener("click", () => {
    postNativeMessage("open-server");
});

/** Restores the locally saved server address when the page loads. */
function setServerAddress(address) {
    document.getElementById("server-address").value = address;
}

const serverAddress = document.getElementById("server-address");
serverAddress.addEventListener("change", () => {
    postNativeMessage({ action: "save-server-address", address: serverAddress.value });
});
serverAddress.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
        serverAddress.blur();
    }
});
