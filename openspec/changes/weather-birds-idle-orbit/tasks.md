## 1. Bird Idle Orbit

- [ ] 1.1 Add a subtle idle orbit motion for the bird container in the main weather scene only
- [ ] 1.2 Keep birds attached under the sun hierarchy so manual rotation still moves birds and sun together
- [ ] 1.3 Preserve imported bird local animation while applying idle orbit at the container level

## 2. Interaction Handoff

- [ ] 2.1 Stop idle bird orbit when weather scene drag interaction begins
- [ ] 2.2 Ensure slow drag and fast drag keep bird and sun aligned as one system
- [ ] 2.3 Keep sun-detail behavior unchanged with no new idle bird orbit

## 3. Validation

- [ ] 3.1 Verify main screen starts with a slow bird orbit around the sun
- [ ] 3.2 Verify slow drag stops idle orbit and keeps bird/sun synchronized
- [ ] 3.3 Verify fast drag stops idle orbit and keeps bird/sun synchronized
- [ ] 3.4 Verify sun-detail screen behavior is unchanged
