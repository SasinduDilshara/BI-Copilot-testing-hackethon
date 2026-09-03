import ballerina/http;

service /'client on new http:Listener(8082) {

    resource function post move(MoveRequest moveRequest) returns string|http:InternalServerError {
        string|error confirmation = sendPositionUpdate(moveRequest.playerId, moveRequest.x, moveRequest.y,
                moveRequest.direction, moveRequest.speed);
        if confirmation is error {
            return {
                body: string `Failed to send position update: ${confirmation.message()}`
            };
        }
        return confirmation;
    }
}
