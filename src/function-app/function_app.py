import azure.functions as func
import logging
import sys
import json
from datetime import datetime

app = func.FunctionApp()

@app.route(route="helloworld", auth_level=func.AuthLevel.FUNCTION)
@app.service_bus_queue_output(arg_name="msg", 
                               connection="ServiceBusConnection", 
                               queue_name="sbq-sample-01")
def helloworld(req: func.HttpRequest, msg: func.Out[str]) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')
    
    # Extract HTTP headers
    headers_dict = dict(req.headers)
    
    # Create message with header information
    message_data = {
        "timestamp": datetime.now().isoformat(),
        "method": req.method,
        "url": req.url,
        "headers": headers_dict,
        "function_name": "helloworld"
    }
    
    # Send message to Service Bus queue
    try:
        msg.set(json.dumps(message_data))
        logging.info(f'Successfully sent message to Service Bus queue with {len(headers_dict)} headers')
    except Exception as e:
        logging.error(f'Failed to send message to Service Bus: {str(e)}')
    
    version = sys.version_info
    return func.HttpResponse(
        f"Hello world! Azure Function running on Python v{version.major}.{version.minor}.",
        status_code=200
    )