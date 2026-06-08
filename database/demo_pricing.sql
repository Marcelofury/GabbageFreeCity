-- Demo pricing update
UPDATE subscription_plans
SET monthly_price_ugx = 1000, prepay_price_ugx = 3000
WHERE weekly_collections = 1 AND monthly_collections = 4;

UPDATE subscription_plans
SET monthly_price_ugx = 2000, prepay_price_ugx = 6000
WHERE weekly_collections = 2 AND monthly_collections = 8;
