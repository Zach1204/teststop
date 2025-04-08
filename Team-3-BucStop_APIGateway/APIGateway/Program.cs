var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register HttpClientg
builder.Services.AddHttpClient();

// This creates the timestamp for the logger.
builder.Logging.AddSimpleConsole(options =>
{
    options.IncludeScopes = true;
    options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    // Production configurations
    // Disable server header for security
    app.Use((context, next) =>
    {
        context.Response.Headers.Remove("Server");
        return next();
    });

    // Handle forwarded headers from AWS load balancers
    app.Use((context, next) =>
    {
        if (context.Request.Headers.ContainsKey("X-Forwarded-Proto") && 
            context.Request.Headers["X-Forwarded-Proto"] == "https")
        {
            context.Request.Scheme = "https";
        }
        return next();
    });

    app.Logger.LogInformation("API Gateway running in Production mode");
}

//app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
