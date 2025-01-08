document.addEventListener("keydown", function (event) {
    if (event.altKey && event.key === "Tab") {
        event.preventDefault();
        safari.extension.dispatchMessage("Option+Tab Pressed");
        console.log("Option+Tab Pressed")
    }
});

window.onbeforeunload = function () {
    safari.extension.dispatchMessage("Tab is closed");
};
