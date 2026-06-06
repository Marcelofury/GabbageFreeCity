-- Update subscription plan prices
UPDATE subscription_plans
SET monthly_price_ugx = 30000, prepay_price_ugx = 90000
WHERE weekly_collections = 1 AND monthly_collections = 4;

UPDATE subscription_plans
SET monthly_price_ugx = 60000, prepay_price_ugx = 180000
WHERE weekly_collections = 2 AND monthly_collections = 8;
