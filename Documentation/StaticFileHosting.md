 # Static File Hosting in BucStop Games

## Overview
Each game microservice (Tetris, Pong, and Snake) now has static file hosting to serve their client-side files directly. This document will just help explain how static file hosting works in our project and how we can take advantage of it.

## Implementation
Static file hosting is enabled in each game's `Program.cs` with the following and can be considered *middleware*:
```csharp
app.UseStaticFiles();
```

## Project Structure
To visually simplify where this is happening because the file structure can be a bit confusing:
```
GameService/
├── wwwroot/              
│   ├── index.html       
│   ├── css/             
│   ├── js/              # JavaScript files to be hosted
│   └── assets/          
├── **Program.cs**       # Contains static file middleware
└── Controllers/
```

## How It Works
1. When a request comes in (e.g., `http://tetris-service:5001/images/logo.png` or for the js):
   - The `UseStaticFiles` checks the `wwwroot` folder
   - If the file exists, it's served directly - no issues
   - If not found, error

2. URL Mapping:
   - Files in `wwwroot` are served from the root URL
   - Example: `wwwroot/js/game.js` → `http://service:port/js/game.js`

## Benefits for Our Project
Static file hosting allows each game's JavaScript files to be served directly from their respective microservices. For example, when Tetris's frontend code needs to load `game.js`, it can access it directly from the Tetris microservice at `http://tetris-service/js/game.js`, without needing a separate file server or complex routing setup. Through the API Gateway, these files can be grabbed using a standard API call like `https://api.bucstop.com/tetris/js/game.js` or whatever we want it to be, making it (hopefully) straightforward to fetch game files from the frontend while maintaining our microservice architecture.

## Testing Static File Hosting

### *Uncontainerized - Standard*
Assuming you have at least the WebApp running and Tetris (not containerized), you can do the following from the CLI:
- Using curl.exe with -k flag for HTTPS (not sure why PS `curl` alias can't access `-k` flag)
   - `curl.exe -k https://localhost:2626/js/tetris.js`

- Or using Invoke-WebRequest
   - `Invoke-WebRequest -Uri "https://localhost:2626/js/tetris.js"`

### *Containerized*
Assuming you have built and run at least the WebApp container and Tetris container, you can do the following:

- Again, using the curl command from the CLI, now just on port 8084:
   - `curl http://localhost:8084/js/tetris.js `



## Additional Resources
- [ASP.NET Core Static Files Documentation](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/static-files)
- [Static File Middleware Configuration](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/static-files#serve-files-outside-of-web-root)