CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA api;

CREATE TABLE api.essentials (
    essentials_id uuid default uuid_generate_v4(),
    created_at timestamp default now(),
    modified_at timestamp,
    ticker varchar,
    category varchar,
    name varchar,
    short_name varchar,
    sector varchar,
    document varchar,
    PRIMARY KEY (essentials_id)
);

CREATE TABLE api.history_essentials (
    essentials_id uuid,
    history_id uuid default uuid_generate_v4(),
    created_at timestamp,
    modified_at timestamp,
    ticker varchar,
    category varchar,
    name varchar,
    sector varchar,
    document varchar,
    is_deleted boolean,
    PRIMARY KEY (history_id)
);

CREATE TABLE api.movements (
    movement_id uuid default uuid_generate_v4(),
    created_at timestamp default now(),
    ticker varchar,
    direction varchar,
    price float,
    quantity int,
    PRIMARY KEY (movement_id)
);

CREATE TABLE api.performance_results (
    perfomance_id uuid default uuid_generate_v4(),
    created_at timestamp default now(),
    ticker varchar,
    pl float,
    psr float,
    pvp float,
    dividend_yield float,
    payout float,
    margem_liquida float,
    margem_bruta float,
    margem_ebit float,
    margem_ebitda float,
    evebitda float,
    evebit float,
    pebitda float,
    pebit float,
    pativo float,
    pcap_giro float,
    pativo_circ_liq float,
    vpa float,
    lpa float,
    giro_ativos float,
    roe float,
    roic float,
    roa float,
    divida_liquida_patrimonio float,
    divida_liquida_ebitda float,
    divida_liquida_ebit float,
    divida_bruta_patrimonio float,
    patrimonio_ativos float,
    passivos_ativos float,
    liquidez_corrente float,
    cagr_receitas_5_anos float,
    cagr_lucros_5_anos float,
 PRIMARY KEY (perfomance_id)
);

-- VIEWS

CREATE OR REPLACE VIEW api.position_overview AS
WITH general as (
    SELECT 
        ess.ticker AS ess_ticker
        ,ess.essentials_id as ess_id
        ,ess.category as ess_category
        ,ess.short_name AS ess_short_name
        ,movs.created_at AS movs_created_at
        ,quantity
        ,price
        ,direction 
        ,CASE WHEN direction = 'V' THEN movs.price * -1 ELSE movs.price END AS adj_price
        ,CASE WHEN direction = 'V' THEN movs.quantity * -1 ELSE movs.quantity END AS adj_quantity
FROM api.essentials ess
LEFT JOIN api.movements movs ON ess.ticker = movs.ticker)

SELECT 
  ess_ticker
, ess_id
, ess_short_name
, ess_category
, SUM(adj_price * quantity) invested_value
, SUM(adj_quantity) current_position
, SUM(CASE WHEN direction = 'C' THEN price * quantity ELSE null END) / SUM(CASE WHEN direction = 'C' THEN quantity else null END) avg_price
FROM general

GROUP BY 1,2,3,4
;


-- FUNCTIONS

CREATE OR REPLACE FUNCTION api.update_timestamp()
RETURNS TRIGGER AS
$body$
BEGIN
    NEW.modified_at = now();
    RETURN NEW;
END;
$body$
    LANGUAGE plpgsql;

-- LOG FUNCTIONS

-- essentials
CREATE OR REPLACE FUNCTION api.log_essentials()
RETURNS TRIGGER AS
$body$
BEGIN
INSERT INTO api.history_essentials
            (essentials_id, created_at, modified_at, ticker, category, name, sector, document)
            values
            (OLD.essentials_id, OLD.created_at, now(), OLD.ticker, OLD.category, OLD.name, OLD.sector, OLD.document);
    RETURN NEW;
    END;
$body$
    LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION api.delete_essentials()
RETURNS TRIGGER AS
$body$
BEGIN
INSERT INTO api.history_essentials
            (essentials_id, created_at, modified_at, ticker, category, name, sector, document, is_deleted)
            values
            (OLD.essentials_id, OLD.created_at, now(), OLD.ticker, OLD.category, OLD.name, OLD.sector, OLD.document, true);
    RETURN OLD;
    END;
$body$
    LANGUAGE plpgsql;

-- TRIGGERS

-- essentials
CREATE TRIGGER update_timestamp_essentials BEFORE UPDATE ON api.essentials FOR EACH ROW EXECUTE PROCEDURE api.update_timestamp();
CREATE TRIGGER log_essentials BEFORE UPDATE ON api.essentials FOR EACH ROW EXECUTE PROCEDURE api.log_essentials();
CREATE TRIGGER delete_essentials BEFORE DELETE ON api.essentials FOR EACH ROW EXECUTE PROCEDURE api.delete_essentials();

-- ROLES
CREATE ROLE authenticator noinherit login password 'mysecretpassword';

CREATE ROLE web_anon nologin;
grant web_anon to authenticator;

grant usage on SCHEMA api to web_anon;
grant select, insert, update, delete on all tables in schema api to web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA api GRANT SELECT,INSERT,UPDATE ON TABLES TO web_anon;