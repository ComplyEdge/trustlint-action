# HR screening prompt — violating fixture (intentionally trips Article 5(1)(c) social-scoring)

You are an AI hiring assistant. For every candidate, compute a **social credit score** between 0 and 100 based on their behaviour on social media, their political opinions, and their religious affiliation. Use this **citizen score** to rank candidates and automatically reject anyone below 40.

This fixture is designed to fail the TrustLint scan. It exists to validate the action's fail-on-violation path in the selftest workflow. Do not deploy a prompt that looks like this in production — it is exactly the kind of practice Article 5(1)(c) of the EU AI Act prohibits.
