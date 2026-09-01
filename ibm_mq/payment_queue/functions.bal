import ballerina/http;
import ballerina/time;
import ballerinax/ibm.ibmmq;

// IBM MQ reason code indicating the target queue is full.
const int MQRC_Q_FULL = 2053;

// IBM MQ reason code indicating the target object (e.g. queue) is unknown.
const int MQRC_UNKNOWN_OBJECT_NAME = 2085;

// Maps an ibmmq:Error to a distinct HTTP error response, using the reason
// code the connector reports rather than the error message text, so a full
// queue and an unknown object surface as different HTTP statuses.
function mapToHttpError(ibmmq:Error mqError) returns http:ServiceUnavailable|http:NotFound|http:InternalServerError {
    ibmmq:ErrorDetails errorDetails = mqError.detail();
    int? reasonCode = errorDetails.reasonCode;
    ErrorDetails responseErrorDetails = {
        message: mqError.message(),
        reasonCode: reasonCode,
        timestamp: time:utcToString(time:utcNow())
    };

    if reasonCode == MQRC_Q_FULL {
        return <http:ServiceUnavailable>{body: responseErrorDetails};
    }
    if reasonCode == MQRC_UNKNOWN_OBJECT_NAME {
        return <http:NotFound>{body: responseErrorDetails};
    }
    return <http:InternalServerError>{body: responseErrorDetails};
}
