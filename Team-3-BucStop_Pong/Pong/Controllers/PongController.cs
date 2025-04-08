using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;

namespace Pong
{
    [ApiController]
    [Route("[controller]")]
    public class PongController : ControllerBase
    {
        private static readonly List<GameInfo> TheInfo = new List<GameInfo>
        {
            new GameInfo { 
                Id = 3,
                Title = "Pong",
                Content = "~/js/pong.js",
                Author = "Fall 2023 Semester",
                DateAdded = "",
                Description = "Pong is a classic arcade game where the player uses a paddle to hit a ball against a computer's paddle. Either party scores when the ball makes it past the opponent's paddle.",
                HowTo = "Control with arrow keys.",
                Thumbnail = "/images/pong.jpg"
            }

        };

        private readonly ILogger<PongController> _logger;

        public PongController(ILogger<PongController> logger)
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