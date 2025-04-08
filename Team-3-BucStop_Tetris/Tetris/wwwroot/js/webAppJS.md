**Minor changes from the webApp**

==ShowStartScreen() is scripted at the bottom of the file on WebApp==
function showStartScreen() {
    context.font = '36px Arial';
    context.textAlign = 'center';
    context.fillText('Press space to start', canvas.width / 2, canvas.height / 2);
}

// on keyboard press of space, start the game.
document.body.onkeyup = function (e) {
    if (e.keyCode == 32) {
        rAF = requestAnimationFrame(loop);
    }
}

showStartScreen();

==This was another change on webApp JS==
 Show score to website, updated after the above code runs
    const playerScore = document.getElementById("playerScore");

    playerScore.textContent = Current Score: ${score};

    tetromino = getNextTetromino();