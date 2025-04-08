using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;
using static System.Net.WebRequestMethods;

namespace Tetris
{
    [ApiController]
    [Route("[controller]")]
    public class TetrisController : ControllerBase
    {
        private static readonly List<GameInfo> TheInfo = new List<GameInfo>
        {
            new GameInfo {

                Id = 2,
                Title = "Tetris",
                Author = "Fall 2023 Semester",
                //Content = "~/js/tetris.js", //changing URL now that the MS hosts game code
                // need to probably change this url so that it is aware of the environment dynamically?
                // i think this would mean using one of the app settings variables instead of hard coding
                Content = "https://localhost:2626/js/tetris.js",
                DateAdded = "",
                Description = "Tetris is a classic arcade puzzle game where the player has to arrange falling blocks, also known as Tetronimos, of different shapes and colors to form complete rows on the bottom of the screen. The game gets faster and harder as the player progresses, and ends when the Tetronimos reach the top of the screen.",
                HowTo = "Control with arrow keys: Up arrow to spin, down to speed up fall, space to insta-drop.",
                Thumbnail = "/images/tetris.jpg"
            }
        };

        private readonly ILogger<TetrisController> _logger;

        public TetrisController(ILogger<TetrisController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IEnumerable<GameInfo> Get()
        {
            return TheInfo;
        }
    }
}