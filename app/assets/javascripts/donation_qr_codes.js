/* eslint-disable no-unused-vars */
/* global html2canvas */

function changeCode(id) {
  const activeQRCode = document.querySelector("qr-code.\\!block");
  document.getElementById("downloadButton").innerText = "Download";
  if (activeQRCode) {
    activeQRCode.classList.remove("!block");
  }
  document.getElementById(`qrCode--${id}`).classList.add("!block");
}

function saveActiveQRCodeAsImage() {
  document.getElementById("downloadButton").innerText = "Downloading...";
  const activeQRCode = document.querySelector("qr-code.\\!block");
  if (!activeQRCode) {
    return;
  }
  html2canvas(activeQRCode, {
    scale: 4,
    backgroundColor: null,
    useCORS: true,
  }).then((canvas) => {
    const imageDataURL = canvas.toDataURL("image/png");
    const downloadLink = document.createElement("a");
    downloadLink.href = imageDataURL;
    downloadLink.download = "qr_code.png";
    downloadLink.click();
    document.getElementById("downloadButton").innerText = "Download";
  })
    .catch((error) => {
      console.error(error);
      document.getElementById("downloadButton").innerText = "Try Again";
    });
}
