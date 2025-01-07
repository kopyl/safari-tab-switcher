document.addEventListener("DOMContentLoaded", function(event) {
    safari.extension.dispatchMessage("Hello World!");
});

document.addEventListener("keydown", function (event) {
    if (event.altKey && event.key === "Tab") {
        event.preventDefault();
        safari.extension.dispatchMessage("Option+Tab Pressed");
    }
});
