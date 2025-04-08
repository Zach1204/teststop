using BucStop;
using BucStop.Services;
using Serilog;
using Serilog.Filters;

/*
 * This is the base program which starts the project.
 */

var builder = WebApplication.CreateBuilder(args);

// Sets up Serilog for logging to console and log file
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("Logs/logs.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7) // Creates a new log file each day and keeps up to 7 log files (7 days)
    .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(Matching.WithProperty("Category", "APIRequests"))
        .WriteTo.File("Logs/api_requests.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)) // Creates a new log file that takes in failed api_requests
    .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(Matching.WithProperty("Category", "InvalidLogin"))
        .WriteTo.File("Logs/invalid_login.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)) // Creates a new log file that takes in failed login errors
     .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(Matching.WithProperty("Category", "GameSuccess"))
        .WriteTo.File("Logs/game_success.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)) // Creates a new log file that takes in successful api_requests
         .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(Matching.WithProperty("Category", "PageLoadTimes"))
        .WriteTo.File("Logs/page_load_times.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)) // Creates a new log file that takes in failed page load times
     .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(Matching.WithProperty("Category", "APIHeartbeat"))
        .WriteTo.File("Logs/api_heartbeat.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)) // Creates a new log file that takes in API HeartBeats
     .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(Matching.WithProperty("Category", "UserActivity"))
        .WriteTo.File("Logs/user_activity.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7)) // Creates a new log file for user activity
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container.
builder.Services.AddControllersWithViews();

var provider=builder.Services.BuildServiceProvider();
var configuration=provider.GetRequiredService<IConfiguration>();

builder.Services.AddHttpClient<MicroClient>(client =>
{
    var baseAddress = new Uri(configuration.GetValue<string>("Gateway"));
    client.BaseAddress = baseAddress;
});

// Add HTTP clients for each microservice
builder.Services.AddHttpClient("Snake", client =>
{
    var baseAddress = new Uri(configuration.GetValue<string>("Microservices:Snake"));
    client.BaseAddress = baseAddress;
});

builder.Services.AddHttpClient("Pong", client =>
{
    var baseAddress = new Uri(configuration.GetValue<string>("Microservices:Pong"));
    client.BaseAddress = baseAddress;
});

builder.Services.AddHttpClient("Tetris", client =>
{
    var baseAddress = new Uri(configuration.GetValue<string>("Microservices:Tetris"));
    client.BaseAddress = baseAddress;
});

builder.Services.AddAuthentication("CustomAuthenticationScheme").AddCookie("CustomAuthenticationScheme", options =>
{
    options.LoginPath = "/Account/Login";
});

builder.Services.AddSingleton<GameService>();
builder.Services.AddHostedService<ApiHeartbeatService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
    
    // Production-specific configurations for AWS
    // Disable server header
    app.Use((context, next) =>
    {
        context.Response.Headers.Remove("Server");
        return next();
    });

    // Configure for running behind a proxy/load balancer if needed
    app.Use((context, next) =>
    {
        if (context.Request.Headers.ContainsKey("X-Forwarded-Proto") && 
            context.Request.Headers["X-Forwarded-Proto"] == "https")
        {
            context.Request.Scheme = "https";
        }
        return next();
    });

    // Set stricter CSP headers for production
    app.Use((context, next) =>
    {
        context.Response.Headers.Add("Content-Security-Policy", 
            "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'; font-src 'self';");
        return next();
    });

    Log.Information("Application running in Production mode");
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

//Handles routing to "separate" game pages by setting the Play page to have subpages depending on ID
app.MapControllerRoute(
    name: "Games",
    pattern: "Games/{action}/{id?}",
    defaults: new { controller = "Games", action = "Index" });

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
