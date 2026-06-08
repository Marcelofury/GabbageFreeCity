-- Demo pricing update
UPDATE subscription_plans
SET monthly_price_ugx = 200, prepay_price_ugx = 600
WHERE weekly_collections = 1 AND monthly_collections = 4;

UPDATE subscription_plans
SET monthly_price_ugx = 400, prepay_price_ugx = 1200
WHERE weekly_collections = 2 AND monthly_collections = 8;
