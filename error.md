Traceback (most recent call last):
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 149, in __init__
    self._dbapi_connection = engine.raw_connection()
                             ~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 3294, in raw_connection
    return self.pool.connect()
           ~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 445, in connect
    return _ConnectionFairy._checkout(self)
           ~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 1317, in _checkout
    fairy = _ConnectionRecord.checkout(pool)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 709, in checkout
    rec = pool._do_get()
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/impl.py", line 176, in _do_get
    with util.safe_reraise():
         ~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/util/langhelpers.py", line 166, in __exit__
    raise exc_value.with_traceback(exc_tb)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/impl.py", line 174, in _do_get
    return self._create_connection()
           ~~~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 386, in _create_connection
    return _ConnectionRecord(self)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 671, in __init__
    self.__connect()
    ~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 916, in __connect
    with util.safe_reraise():
         ~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/util/langhelpers.py", line 166, in __exit__
    raise exc_value.with_traceback(exc_tb)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 912, in __connect
    self.dbapi_connection = connection = pool._invoke_creator(self)
                                         ~~~~~~~~~~~~~~~~~~~~^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/create.py", line 645, in connect
    return dialect.connect(*cargs_tup, **cparams)
           ~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/default.py", line 869, in connect
    return self.loaded_dbapi.connect(*cargs, **cparams)  # type: ignore[no-any-return]  # NOQA: E501
           ~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 373, in __init__
    self.connect()
    ~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 702, in connect
    self._request_authentication()
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 1010, in _request_authentication
    auth_packet = self._read_packet()
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 810, in _read_packet
    packet.raise_for_error()
    ~~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/protocol.py", line 219, in raise_for_error
    err.raise_mysql_exception(self._data)
    ~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/err.py", line 154, in raise_mysql_exception
    raise errorclass(errno, errval, sqlstate=sqlstate)
pymysql.err.OperationalError: (1044, "Access denied for user 'supplidar'@'localhost' to database 'supplidar'")

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/database.py", line 101, in <module>
    init_db()
    ~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/database.py", line 96, in init_db
    Base.metadata.create_all(bind=engine)
    ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/sql/schema.py", line 6700, in create_all
    bind._run_ddl_visitor(
    ~~~~~~~~~~~~~~~~~~~~~^
        ddl.SchemaGenerator, self, checkfirst=checkfirst, tables=tables
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    )
    ^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 3244, in _run_ddl_visitor
    with self.begin() as conn:
         ~~~~~~~~~~^^
  File "/usr/lib/python3.14/contextlib.py", line 141, in __enter__
    return next(self.gen)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 3234, in begin
    with self.connect() as conn:
         ~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 3270, in connect
    return self._connection_cls(self)
           ~~~~~~~~~~~~~~~~~~~~^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 151, in __init__
    Connection._handle_dbapi_exception_noconnection(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        err, dialect, engine
        ^^^^^^^^^^^^^^^^^^^^
    )
    ^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 2427, in _handle_dbapi_exception_noconnection
    raise sqlalchemy_exception.with_traceback(exc_info[2]) from e
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 149, in __init__
    self._dbapi_connection = engine.raw_connection()
                             ~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/base.py", line 3294, in raw_connection
    return self.pool.connect()
           ~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 445, in connect
    return _ConnectionFairy._checkout(self)
           ~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 1317, in _checkout
    fairy = _ConnectionRecord.checkout(pool)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 709, in checkout
    rec = pool._do_get()
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/impl.py", line 176, in _do_get
    with util.safe_reraise():
         ~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/util/langhelpers.py", line 166, in __exit__
    raise exc_value.with_traceback(exc_tb)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/impl.py", line 174, in _do_get
    return self._create_connection()
           ~~~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 386, in _create_connection
    return _ConnectionRecord(self)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 671, in __init__
    self.__connect()
    ~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 916, in __connect
    with util.safe_reraise():
         ~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/util/langhelpers.py", line 166, in __exit__
    raise exc_value.with_traceback(exc_tb)
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/pool/base.py", line 912, in __connect
    self.dbapi_connection = connection = pool._invoke_creator(self)
                                         ~~~~~~~~~~~~~~~~~~~~^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/create.py", line 645, in connect
    return dialect.connect(*cargs_tup, **cparams)
           ~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/sqlalchemy/engine/default.py", line 869, in connect
    return self.loaded_dbapi.connect(*cargs, **cparams)  # type: ignore[no-any-return]  # NOQA: E501
           ~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 373, in __init__
    self.connect()
    ~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 702, in connect
    self._request_authentication()
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 1010, in _request_authentication
    auth_packet = self._read_packet()
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/connections.py", line 810, in _read_packet
    packet.raise_for_error()
    ~~~~~~~~~~~~~~~~~~~~~~^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/protocol.py", line 219, in raise_for_error
    err.raise_mysql_exception(self._data)
    ~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^
  File "/home/ceyhun/Desktop/suppLIDAR/SuppLIDAR/venv/lib/python3.14/site-packages/pymysql/err.py", line 154, in raise_mysql_exception
    raise errorclass(errno, errval, sqlstate=sqlstate)
sqlalchemy.exc.OperationalError: (pymysql.err.OperationalError) (1044, "Access denied for user 'supplidar'@'localhost' to database 'supplidar'")
(Background on this error at: https://sqlalche.me/e/21/e3q8)
