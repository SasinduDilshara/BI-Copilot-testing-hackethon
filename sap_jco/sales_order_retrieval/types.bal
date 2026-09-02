// ============================================================================
// Type definitions for the SAP ECC Sales Order Retrieval integration.
//
// These records model:
//   1. The inbound request from the customer service application.
//   2. The SAP BAPI_SALESORDER_GETDETAIL input/output structures (representative
//      subset of the real SAP BAPI structures BAPISDHD1 / BAPISDITM / BAPIRET2).
//   3. The transformed, integration-friendly sales order representation.
//   4. The outbound API responses for every outcome (success, SAP error,
//      SAP connection error, partial success on email failure).
// ============================================================================

# Inbound request carrying the sales order number to look up in SAP ECC.
public type SalesOrderRequest record {|
    string salesOrder;
|};

# BAPI import parameter structure for BAPI_SALESORDER_GETDETAIL.
# Mirrors the real SAP interface where SALESDOCUMENT is the sales document number.
public type BapiSalesOrderGetDetailInput record {|
    string SALESDOCUMENT;
|};

# Representative subset of the SAP standard structure BAPIRET2 (Return Parameter).
public type BapiReturn record {|
    string TYPE = "";
    string ID = "";
    string number = "";
    string MESSAGE = "";
    string LOG_NO = "";
    string LOG_MSG_NO = "";
    string MESSAGE_V1 = "";
    string MESSAGE_V2 = "";
|};

# Representative subset of the SAP standard structure BAPISDHD1 (Sales Document Header).
public type SapOrderHeader record {|
    string DOC_NUMBER = "";
    string DOC_TYPE = "";
    string SALES_ORG = "";
    string DISTR_CHAN = "";
    string DIVISION = "";
    string SOLD_TO = "";
    string CUST_NAME = "";
    string DOC_DATE = "";
    string CURRENCY = "";
    decimal NET_VALUE = 0;
|};

# Representative subset of the SAP standard structure BAPISDITM (Sales Document Item),
# returned as an internal table (one row per sales order item).
public type SapOrderItem record {|
    string ITM_NUMBER = "";
    string MATERIAL = "";
    string SHORT_TEXT = "";
    decimal REQ_QTY = 0;
    string SALES_UNIT = "";
    decimal NET_VALUE = 0;
|};

# Aggregated result of invoking BAPI_SALESORDER_GETDETAIL — the RETURN structure,
# the order header structure, and the order items internal table.
public type BapiSalesOrderGetDetailOutput record {|
    BapiReturn RETURN;
    SapOrderHeader ORDER_HEADER;
    SapOrderItem[] ORDER_ITEMS;
|};

# Customer information extracted from the SAP order header.
public type CustomerInfo record {|
    string id;
    string name;
|};

# A single transformed sales order line item.
public type SalesOrderItem record {|
    string itemNumber;
    string material;
    string description;
    decimal quantity;
    string unit;
    decimal netValue;
|};

# The transformed, canonical sales order representation used for the email
# notification and for any downstream processing.
public type SalesOrderDetails record {|
    string salesOrder;
    CustomerInfo customer;
    string salesOrganization;
    string distributionChannel;
    string documentDate;
    string currency;
    decimal netValue;
    SalesOrderItem[] items;
|};

# Successful end-to-end response — SAP retrieval succeeded and the email was sent.
public type SuccessResponse record {|
    string status = "SUCCESS";
    string salesOrder;
    string sapSystem = "SAP ECC";
    string bapi = "BAPI_SALESORDER_GETDETAIL";
    string sapStatus = "SUCCESS";
    string emailStatus = "SENT";
    string recipient;
|};

# SAP ECC retrieved the order successfully, but the SMTP send failed.
public type PartialSuccessResponse record {|
    string status = "PARTIAL_SUCCESS";
    string salesOrder;
    string sapStatus = "SUCCESS";
    string emailStatus = "FAILED";
    string errorCode = "SMTP_ERROR";
    string message;
|};

# The BAPI executed but returned a business-level (functional) error, e.g. the
# sales order does not exist.
public type SapBusinessErrorResponse record {|
    string status = "ERROR";
    string salesOrder;
    string sapStatus = "FAILED";
    string errorCode = "SAP_BAPI_ERROR";
    string message;
|};

# SAP JCo could not establish or maintain a connection/session with SAP ECC
# (invalid credentials, host unreachable, wrong system number/client, timeout, etc).
public type SapConnectionErrorResponse record {|
    string status = "ERROR";
    string errorCode = "SAP_CONNECTION_ERROR";
    string message;
|};

# Generic validation/technical error response (e.g. malformed request).
public type GenericErrorResponse record {|
    string status = "ERROR";
    string errorCode;
    string message;
|};
