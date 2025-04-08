# Snake
### A Team Redacted Project
### Members:
> Kurt Brewer, Josh Rucevice, Charlie Shahan,
> Ethan Webb, Ethan Hensley, Patrick Vergason, Bryson Brandon
#### CSCI 4350
#### Fall 2023, East Tennessee State University

### Overview:
This is a microservice that returns snake game info to Bucstop

### Project Structure:
* The application handles HTTP calls in the SnakeController.cs file in the /Snake/Controllers directory.
* It only handles an HTTP Get call to the path /Snake. So if the application was running locally, you would call [http://localhost/Snake](http://localhost/Snake).
* This application is deployed alongside the BucStop project with docker compose, see [BOBBY Project](https://github.com/chrisseals98/BOBBY) for more details.

### Help
For more documentation on how to run locally and how to set up deployments, see the google docs below:
* [Running Locally](https://docs.google.com/document/d/1gfUpjZNfqWyv1ohUW1IaS8fOhXp0hOx6tFQVXBADa8Q/edit?usp=sharing)
* [How to Deploy](https://docs.google.com/document/d/1i0edcmvZm_j0zQLYiigNliW39FJuJbmhkxOCCb2NbVs/edit?usp=sharing)
