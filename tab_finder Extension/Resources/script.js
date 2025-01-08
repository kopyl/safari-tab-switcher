document.addEventListener("keydown", function (event) {
    if (event.altKey && event.key === "Tab") {
        event.preventDefault();
        safari.extension.dispatchMessage("opttab");
        console.log("Option+Tab Pressed")
    }
});

window.onbeforeunload = function () {
    safari.extension.dispatchMessage("tabclose");
};
