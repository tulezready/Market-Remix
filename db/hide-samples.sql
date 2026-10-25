-- 023: take the sample (demo) businesses and the Sunshyne test entry off the
-- public site before trial businesses and the Division are shown it.
-- Hidden, not deleted: approved = false keeps them out of public_smes and the
-- catalogue; their rows, products and photos stay. To bring a sample back:
--   update smes set approved = true where is_sample;
update smes set approved = false where is_sample and approved;
update smes set approved = false where registered_name = 'Sunshyne Fresh Produce' and not is_sample and approved;
