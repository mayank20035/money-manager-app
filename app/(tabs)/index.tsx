import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  Check,
  Filter,
  Info,
  Minus,
  Pencil,
  Plus,
  RotateCcw,
  Trash2,
  X
} from 'lucide-react-native';
import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Modal,
  Platform,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  TouchableOpacity,
  View
} from 'react-native';
// FIX: Use the robust safe area library to prevent overlap
import { SafeAreaView as SafeAreaViewContext } from 'react-native-safe-area-context';

// --- TYPES ---
interface Section {
  id: string;
  name: string;
  currentAmount: number;
  isIncludedInTotal?: boolean;
}

// --- CONSTANTS ---
const STORAGE_KEY = '@money_manager_sections';

const INITIAL_SECTIONS: Section[] = [
  { id: '1', name: 'Usable Money', currentAmount: 0, isIncludedInTotal: true },
  { id: '2', name: 'Invested Money', currentAmount: 0, isIncludedInTotal: true },
];

export default function HomeScreen() {
  // --- STATE ---
  const [sections, setSections] = useState<Section[]>([]);
  const [loading, setLoading] = useState(true);

  // Transaction Modal State
  const [isModalVisible, setIsModalVisible] = useState(false);
  const [activeSectionId, setActiveSectionId] = useState<string | null>(null);
  const [transactionType, setTransactionType] = useState<'deposit' | 'withdraw'>('deposit');
  
  // Inputs
  const [amountInput, setAmountInput] = useState('');
  const [withdrawItems, setWithdrawItems] = useState<string[]>(['']); 
  const [isSplitEnabled, setIsSplitEnabled] = useState(false);
  const [splitAllocations, setSplitAllocations] = useState<Record<string, string>>({});

  // Transfer/Split Modal State
  const [isTransferModalVisible, setIsTransferModalVisible] = useState(false);
  const [transferSourceId, setTransferSourceId] = useState<string | null>(null);
  const [transferAmount, setTransferAmount] = useState('');
  // We reuse splitAllocations for the transfer logic as well

  // Other Modals
  const [isNewSectionModalVisible, setIsNewSectionModalVisible] = useState(false);
  const [newSectionName, setNewSectionName] = useState('');
  const [isEditModalVisible, setIsEditModalVisible] = useState(false);
  const [editSectionId, setEditSectionId] = useState<string | null>(null);
  const [editSectionName, setEditSectionName] = useState('');
  
  // Filter Modal
  const [isFilterModalVisible, setIsFilterModalVisible] = useState(false);

  // --- STORAGE HELPERS ---

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    if (!loading && sections.length > 0) {
      saveData(sections);
    }
  }, [sections, loading]);

  const loadData = async () => {
    try {
      const jsonValue = await AsyncStorage.getItem(STORAGE_KEY);
      if (jsonValue != null) {
        const parsed: Section[] = JSON.parse(jsonValue);
        const migrated = parsed.map(s => ({
          ...s,
          isIncludedInTotal: s.isIncludedInTotal !== undefined ? s.isIncludedInTotal : true
        }));
        setSections(migrated);
      } else {
        setSections(INITIAL_SECTIONS);
      }
    } catch (e) {
      console.error("Failed to load data", e);
      Alert.alert("Error", "Failed to load your data.");
    } finally {
      setLoading(false);
    }
  };

  const saveData = async (data: Section[]) => {
    try {
      const jsonValue = JSON.stringify(data);
      await AsyncStorage.setItem(STORAGE_KEY, jsonValue);
    } catch (e) {
      console.error("Failed to save data", e);
    }
  };

  // --- LOGIC HELPERS ---

  const handleSplitChange = (id: string, val: string) => {
    if (!/^\d*\.?\d*$/.test(val)) return;
    setSplitAllocations(prev => ({ ...prev, [id]: val }));
  };

  const getDistributedPercent = () => {
    return Object.values(splitAllocations).reduce((acc, val) => {
      const num = parseFloat(val || '0');
      return acc + (isNaN(num) ? 0 : num);
    }, 0);
  };

  const getRemainingPercent = () => {
    return parseFloat((100 - getDistributedPercent()).toFixed(2));
  };

  const handleWithdrawItemChange = (text: string, index: number) => {
    const newItems = [...withdrawItems];
    newItems[index] = text;
    setWithdrawItems(newItems);
  };

  const addWithdrawItem = () => {
    setWithdrawItems([...withdrawItems, '']);
  };

  const removeWithdrawItem = (index: number) => {
    const newItems = withdrawItems.filter((_, i) => i !== index);
    setWithdrawItems(newItems.length ? newItems : ['']);
  };

  const getWithdrawTotal = () => {
    return withdrawItems.reduce((acc, val) => {
      const num = parseFloat(val || '0');
      return acc + (isNaN(num) ? 0 : num);
    }, 0);
  };

  const toggleSectionInclusion = (id: string) => {
    setSections(prev => prev.map(s => 
      s.id === id ? { ...s, isIncludedInTotal: !s.isIncludedInTotal } : s
    ));
  };

  // --- MODAL OPENERS ---

  const openTransactionModal = (sectionId: string, type: 'deposit' | 'withdraw') => {
    setActiveSectionId(sectionId);
    setTransactionType(type);
    setAmountInput('');
    setWithdrawItems(['']); 
    setIsSplitEnabled(false);
    setSplitAllocations({});
    setIsModalVisible(true);
  };

  const openEditModal = (section: Section) => {
    setEditSectionId(section.id);
    setEditSectionName(section.name);
    setIsEditModalVisible(true);
  };

  const openTransferModal = (sectionId: string) => {
    setTransferSourceId(sectionId);
    setTransferAmount('');
    setSplitAllocations({});
    setIsTransferModalVisible(true);
  };

  // --- ACTION HANDLERS ---

  const handleTransaction = () => {
    const amount = transactionType === 'deposit' 
      ? parseFloat(amountInput) 
      : getWithdrawTotal();

    if (isNaN(amount) || amount <= 0) {
      Alert.alert("Error", "Please enter a valid amount");
      return;
    }

    if (transactionType === 'withdraw') {
      setSections(prev => prev.map(s => {
        if (s.id === activeSectionId) {
          return { ...s, currentAmount: s.currentAmount - amount };
        }
        return s;
      }));
      setIsModalVisible(false);
      return;
    }

    if (isSplitEnabled && getRemainingPercent() < 0) {
      Alert.alert("Error", "Split percentages exceed 100%");
      return;
    }

    const newSections = sections.map(s => {
      let amountToAdd = 0;
      if (isSplitEnabled) {
        if (s.id === activeSectionId) {
          const percent = getRemainingPercent();
          amountToAdd = (amount * percent) / 100;
        } else {
          const percent = parseFloat(splitAllocations[s.id] || '0');
          amountToAdd = (amount * percent) / 100;
        }
      } else {
        if (s.id === activeSectionId) amountToAdd = amount;
      }
      return { ...s, currentAmount: s.currentAmount + amountToAdd };
    });

    setSections(newSections);
    setIsModalVisible(false);
  };

  const handleSplitTransfer = () => {
    const amount = parseFloat(transferAmount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert("Error", "Please enter a valid amount to distribute");
      return;
    }

    // Validation: Cannot distribute more than available in source
    const sourceSection = sections.find(s => s.id === transferSourceId);
    if (!sourceSection || sourceSection.currentAmount < amount) {
      Alert.alert("Insufficient Funds", `You only have ₹${sourceSection?.currentAmount} in ${sourceSection?.name}.`);
      return;
    }

    if (getRemainingPercent() < 0) {
      Alert.alert("Error", "Total percentage exceeds 100%");
      return;
    }

    // Execute Split Transfer
    let totalDeductedFromSource = 0;
    const updates = new Map<string, number>(); 

    // Calculate distributions
    sections.forEach(s => {
      if (s.id !== transferSourceId) {
        const percent = parseFloat(splitAllocations[s.id] || '0');
        if (percent > 0) {
          const amtToAdd = (amount * percent) / 100;
          updates.set(s.id, amtToAdd);
          totalDeductedFromSource += amtToAdd;
        }
      }
    });

    // Update State
    setSections(prev => prev.map(s => {
      // Source: Deduct the total amount that was distributed
      if (s.id === transferSourceId) {
        return { ...s, currentAmount: s.currentAmount - totalDeductedFromSource };
      }
      // Targets: Add their allocated share
      if (updates.has(s.id)) {
        return { ...s, currentAmount: s.currentAmount + (updates.get(s.id) || 0) };
      }
      return s;
    }));

    setIsTransferModalVisible(false);
    Alert.alert("Success", "Money distributed successfully!");
  };

  const addNewSection = () => {
    if (!newSectionName.trim()) return;
    const newId = Date.now().toString();
    const newSection = { id: newId, name: newSectionName, currentAmount: 0, isIncludedInTotal: true };
    setSections(prev => [...prev, newSection]);
    setNewSectionName('');
    setIsNewSectionModalVisible(false);
  };

  const handleRenameSection = () => {
    if (!editSectionName.trim() || !editSectionId) return;
    setSections(prev => prev.map(s => 
      s.id === editSectionId ? { ...s, name: editSectionName } : s
    ));
    setIsEditModalVisible(false);
  };

  const deleteSection = () => {
    if (!editSectionId) return;
    Alert.alert(
      "Delete Bucket",
      "Are you sure? This will delete the money inside it too.",
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: 'destructive',
          onPress: () => {
            setSections(prev => prev.filter(s => s.id !== editSectionId));
            setIsEditModalVisible(false);
          }
        }
      ]
    );
  };

  const handleResetApp = () => {
    Alert.alert(
      "Reset Dashboard",
      "Are you sure you want to delete all buckets and reset amounts? This cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Reset Everything", 
          style: 'destructive',
          onPress: () => {
            setSections([]); 
            AsyncStorage.removeItem(STORAGE_KEY); 
          }
        }
      ]
    );
  };

  const totalBalance = sections
    .filter(s => s.isIncludedInTotal !== false)
    .reduce((acc, s) => acc + s.currentAmount, 0);

  if (loading) {
    return (
      <View style={[styles.container, {justifyContent:'center', alignItems:'center'}]}>
        <ActivityIndicator size="large" color="#3b82f6"/>
      </View>
    );
  }

  return (
    // FIX: Replaced regular View with SafeAreaViewContext + edges prop for Android/iOS safety
    <SafeAreaViewContext style={styles.container} edges={['top', 'left', 'right', 'bottom']}>
      {/* FIXED HEADER: Now outside ScrollView */}
      <View style={styles.headerContainer}>
          <View style={styles.headerTopRow}>
            <Text style={styles.appTitle}>Dashboard</Text>
            {/* RESET BUTTON */}
            <TouchableOpacity onPress={handleResetApp} style={styles.resetButton}>
              <RotateCcw size={18} color="#9ca3af" />
            </TouchableOpacity>
          </View>

          <View style={styles.totalBalanceCard}>
            <View style={styles.balanceLabelRow}>
              <Text style={styles.balanceLabel}>Total Balance</Text>
              {/* FILTER BUTTON */}
              <TouchableOpacity onPress={() => setIsFilterModalVisible(true)} style={styles.filterButton}>
                <Filter size={14} color="#6b7280" />
              </TouchableOpacity>
            </View>
            <Text style={styles.totalAmount}>₹{totalBalance.toLocaleString('en-US', { minimumFractionDigits: 2 })}</Text>
          </View>
      </View>

      {/* SCROLLABLE CONTENT */}
      <ScrollView contentContainerStyle={{ paddingBottom: 100 }}>
        
        {/* List */}
        <View style={styles.listContainer}>
          {sections.map(section => (
            <View key={section.id} style={[styles.sectionCard, !section.isIncludedInTotal && styles.sectionCardDisabled]}>
              <View style={styles.cardHeader}>
                <View style={{flexDirection:'row', alignItems:'center', gap: 8}}>
                  <Text style={[styles.sectionName, !section.isIncludedInTotal && {color: '#9ca3af'}]}>
                    {section.name}
                  </Text>
                  {!section.isIncludedInTotal && (
                    <Filter size={12} color="#9ca3af" />
                  )}
                </View>
                <View style={{flexDirection: 'row', gap: 8}}>
                  {/* INFO / SPLIT BUTTON */}
                  <TouchableOpacity onPress={() => openTransferModal(section.id)} style={styles.iconButton}>
                    <Info size={16} color="#6b7280" />
                  </TouchableOpacity>
                  {/* EDIT BUTTON */}
                  <TouchableOpacity onPress={() => openEditModal(section)} style={styles.iconButton}>
                    <Pencil size={16} color="#6b7280" />
                  </TouchableOpacity>
                </View>
              </View>

              <View style={styles.cardBody}>
                <View style={styles.amountContainer}>
                  <Text style={[styles.currencyPrefix, !section.isIncludedInTotal && {color: '#d1d5db'}]}>₹</Text>
                  <Text style={[styles.sectionAmount, !section.isIncludedInTotal && {color: '#9ca3af'}]}>
                    {section.currentAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </Text>
                </View>

                <View style={styles.actionRow}>
                  <TouchableOpacity 
                    style={[styles.actionButton, styles.minusButton, !section.isIncludedInTotal && {opacity: 0.5}]}
                    onPress={() => openTransactionModal(section.id, 'withdraw')}
                  >
                    <Minus size={20} color="white" />
                  </TouchableOpacity>
                  
                  <TouchableOpacity 
                    style={[styles.actionButton, styles.plusButton, !section.isIncludedInTotal && {opacity: 0.5}]}
                    onPress={() => openTransactionModal(section.id, 'deposit')}
                  >
                    <Plus size={20} color="white" />
                  </TouchableOpacity>
                </View>
              </View>
            </View>
          ))}
        </View>

        {/* Add New Section */}
        <TouchableOpacity 
          style={styles.addNewTypeBtn}
          onPress={() => setIsNewSectionModalVisible(true)}
        >
          <Plus size={20} color="#3b82f6" />
          <Text style={styles.addNewTypeText}>Add New Bucket</Text>
        </TouchableOpacity>

      </ScrollView>

      {/* --- MODAL: SPLIT & TRANSFER --- */}
      <Modal
        visible={isTransferModalVisible}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setIsTransferModalVisible(false)}
      >
        <KeyboardAvoidingView 
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          style={styles.modalOverlay}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Split & Transfer</Text>
              <TouchableOpacity onPress={() => setIsTransferModalVisible(false)}>
                <X size={24} color="#374151" />
              </TouchableOpacity>
            </View>

            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              
              <Text style={styles.label}>Distribute from <Text style={{color:'#3b82f6'}}>{sections.find(s => s.id === transferSourceId)?.name}</Text></Text>
              
              {/* AMOUNT INPUT */}
              <View style={styles.inputWrapper}>
                <Text style={styles.inputPrefix}>₹</Text>
                <TextInput
                  style={styles.mainInput}
                  placeholder="Amount to Split"
                  placeholderTextColor="#9ca3af"
                  keyboardType="numeric"
                  value={transferAmount}
                  onChangeText={setTransferAmount}
                  autoFocus
                />
              </View>

              <Text style={styles.hintText}>
                Enter percentage to send to other buckets. The rest stays in <Text style={{fontWeight:'700'}}>{sections.find(s => s.id === transferSourceId)?.name}</Text>.
              </Text>

              {sections.filter(s => s.id !== transferSourceId).length === 0 && (
                <Text style={{textAlign:'center', color:'#9ca3af', marginVertical:20, fontStyle:'italic'}}>
                  No other buckets available to transfer to.
                </Text>
              )}

              {/* LIST OF TARGETS FOR SPLIT */}
              {sections
                .filter(s => s.id !== transferSourceId)
                .map(s => {
                  const bucketPercent = splitAllocations[s.id] || '0';
                  const bucketAmount = (parseFloat(transferAmount || '0') * parseFloat(bucketPercent)) / 100;
                  
                  return (
                    <View key={s.id} style={styles.splitRow}>
                      <View style={{flex: 1}}>
                        <Text style={styles.splitName} numberOfLines={1}>{s.name}</Text>
                        <Text style={{fontSize: 12, color: '#3b82f6', fontWeight: 'bold'}}>
                          {bucketAmount > 0 ? `+ ₹${bucketAmount.toLocaleString()}` : '-'}
                        </Text>
                      </View>
                      
                      <View style={styles.splitInputContainer}>
                        <TextInput
                          style={styles.splitInput}
                          placeholder="0"
                          placeholderTextColor="#9ca3af"
                          keyboardType="numeric"
                          value={splitAllocations[s.id] || ''}
                          onChangeText={(val) => handleSplitChange(s.id, val)}
                        />
                        <Text style={styles.percentSign}>%</Text>
                      </View>
                    </View>
                  );
                })}
              
              <View style={styles.splitSummary}>
                <Text style={styles.summaryLabel}>
                  Distributed: {getDistributedPercent()}% | Staying: {getRemainingPercent()}%
                </Text>
              </View>

              <TouchableOpacity style={[styles.confirmBtn, styles.depositBtn]} onPress={handleSplitTransfer}>
                <Check size={20} color="white" />
                <Text style={styles.confirmBtnText}>Confirm Distribution</Text>
              </TouchableOpacity>
              
              <View style={{ height: 40 }} />
            </ScrollView>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      {/* --- MODAL: FILTER SECTIONS --- */}
      <Modal
        visible={isFilterModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setIsFilterModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          {/* Backdrop to close modal */}
          <TouchableOpacity 
            style={StyleSheet.absoluteFill} 
            activeOpacity={1} 
            onPress={() => setIsFilterModalVisible(false)}
          />
          
          {/* Modal Content */}
          <View style={[styles.modalContent, { height: 'auto', maxHeight: '60%' }]}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Include in Total</Text>
              <TouchableOpacity onPress={() => setIsFilterModalVisible(false)}>
                <X size={24} color="#374151" />
              </TouchableOpacity>
            </View>
            
            <ScrollView style={{marginBottom: 20}}>
              {sections.map(s => (
                <View key={s.id} style={styles.filterRowItem}>
                  <Text style={styles.filterRowText}>{s.name}</Text>
                  <Switch
                    value={s.isIncludedInTotal !== false}
                    onValueChange={() => toggleSectionInclusion(s.id)}
                    trackColor={{ false: '#e5e7eb', true: '#bfdbfe' }}
                    thumbColor={s.isIncludedInTotal !== false ? '#3b82f6' : '#f3f4f6'}
                  />
                </View>
              ))}
            </ScrollView>
            
            <TouchableOpacity style={[styles.confirmBtn, styles.depositBtn]} onPress={() => setIsFilterModalVisible(false)}>
              <Text style={styles.confirmBtnText}>Done</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* --- MODAL: TRANSACTION --- */}
      <Modal
        visible={isModalVisible}
        transparent={true}
        animationType="slide"
        onRequestClose={() => setIsModalVisible(false)}
      >
        <KeyboardAvoidingView 
          behavior={Platform.OS === "ios" ? "padding" : "height"}
          style={styles.modalOverlay}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <View>
                <Text style={styles.modalTitle}>
                  {transactionType === 'deposit' ? 'Deposit Money' : 'Spend Money'}
                </Text>
                <Text style={styles.modalSubtitle}>
                  {transactionType === 'deposit' ? 'to' : 'from'} {sections.find(s => s.id === activeSectionId)?.name}
                </Text>
              </View>
              <TouchableOpacity onPress={() => setIsModalVisible(false)} style={styles.closeButton}>
                <X size={24} color="#374151" />
              </TouchableOpacity>
            </View>

            <ScrollView showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
              {transactionType === 'deposit' && (
                <>
                  <Text style={styles.label}>Amount</Text>
                  <View style={styles.inputWrapper}>
                    <Text style={styles.inputPrefix}>+ ₹</Text>
                    <TextInput
                      style={styles.mainInput}
                      placeholder="0.00"
                      placeholderTextColor="#9ca3af"
                      keyboardType="numeric"
                      value={amountInput}
                      onChangeText={setAmountInput}
                      autoFocus
                    />
                  </View>

                  <View style={styles.toggleRow}>
                    <Text style={styles.toggleLabel}>Split this deposit?</Text>
                    <Switch
                      value={isSplitEnabled}
                      onValueChange={setIsSplitEnabled}
                      trackColor={{ false: '#e5e7eb', true: '#bfdbfe' }}
                      thumbColor={isSplitEnabled ? '#3b82f6' : '#f3f4f6'}
                    />
                  </View>

                  {isSplitEnabled && (
                    <View style={styles.splitSection}>
                      <Text style={styles.hintText}>
                        Enter percentages for other buckets. Remainder stays here.
                      </Text>
                      {sections
                        .filter(s => s.id !== activeSectionId)
                        .map(s => (
                          <View key={s.id} style={styles.splitRow}>
                            <Text style={styles.splitName} numberOfLines={1}>{s.name}</Text>
                            <View style={styles.splitInputContainer}>
                              <TextInput
                                style={styles.splitInput}
                                placeholder="0"
                                placeholderTextColor="#9ca3af"
                                keyboardType="numeric"
                                value={splitAllocations[s.id] || ''}
                                onChangeText={(val) => handleSplitChange(s.id, val)}
                              />
                              <Text style={styles.percentSign}>%</Text>
                            </View>
                          </View>
                        ))}
                      <View style={styles.splitSummary}>
                        <Text style={styles.summaryLabel}>
                          Distributed: {getDistributedPercent()}% | Rem: {getRemainingPercent()}%
                        </Text>
                      </View>
                    </View>
                  )}
                </>
              )}

              {transactionType === 'withdraw' && (
                <>
                  <Text style={styles.label}>Expenditure Items</Text>
                  <View style={{ marginBottom: 20 }}>
                    {withdrawItems.map((item, index) => (
                      <View key={index} style={styles.withdrawRow}>
                         <View style={styles.withdrawInputWrapper}>
                           <Text style={styles.withdrawPrefix}>- ₹</Text>
                           <TextInput
                            style={styles.withdrawInput}
                            placeholder="0.00"
                            placeholderTextColor="#9ca3af"
                            keyboardType="numeric"
                            value={item}
                            onChangeText={(text) => handleWithdrawItemChange(text, index)}
                            autoFocus={index === withdrawItems.length - 1}
                           />
                         </View>
                         {withdrawItems.length > 1 && (
                           <TouchableOpacity onPress={() => removeWithdrawItem(index)} style={styles.removeBtn}>
                             <X size={16} color="#ef4444" />
                           </TouchableOpacity>
                         )}
                      </View>
                    ))}
                    <TouchableOpacity onPress={addWithdrawItem} style={styles.addWithdrawItemBtn}>
                      <Plus size={20} color="#3b82f6" />
                      <Text style={styles.addWithdrawItemText}>Add another item</Text>
                    </TouchableOpacity>
                  </View>
                  <View style={styles.totalRow}>
                    <Text style={styles.totalLabel}>Total Spending:</Text>
                    <Text style={styles.totalValue}>₹{getWithdrawTotal().toLocaleString()}</Text>
                  </View>
                </>
              )}

              <TouchableOpacity 
                style={[
                  styles.confirmBtn, 
                  transactionType === 'withdraw' ? styles.withdrawBtn : styles.depositBtn
                ]} 
                onPress={handleTransaction}
              >
                <Check size={20} color="white" />
                <Text style={styles.confirmBtnText}>
                  {transactionType === 'deposit' ? 'Confirm Deposit' : 'Confirm Spend'}
                </Text>
              </TouchableOpacity>
              <View style={{ height: 40 }} />
            </ScrollView>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      <Modal
        visible={isNewSectionModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setIsNewSectionModalVisible(false)}
      >
        <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : "height"} style={styles.modalOverlay}>
          <View style={[styles.modalContent, { height: 'auto', maxHeight: '50%' }]}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>New Bucket</Text>
              <TouchableOpacity onPress={() => setIsNewSectionModalVisible(false)}>
                <X size={24} color="#374151" />
              </TouchableOpacity>
            </View>
            <TextInput
              style={styles.simpleInput}
              placeholder="Bucket Name"
              placeholderTextColor="#9ca3af"
              value={newSectionName}
              onChangeText={setNewSectionName}
              autoFocus
            />
            <TouchableOpacity style={[styles.confirmBtn, styles.depositBtn]} onPress={addNewSection}>
              <Text style={styles.confirmBtnText}>Create Bucket</Text>
            </TouchableOpacity>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      <Modal
        visible={isEditModalVisible}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setIsEditModalVisible(false)}
      >
        <KeyboardAvoidingView behavior={Platform.OS === "ios" ? "padding" : "height"} style={styles.modalOverlay}>
          <View style={[styles.modalContent, { height: 'auto', maxHeight: '50%' }]}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Edit Bucket</Text>
              <TouchableOpacity onPress={() => setIsEditModalVisible(false)}>
                <X size={24} color="#374151" />
              </TouchableOpacity>
            </View>
            <TextInput
              style={styles.simpleInput}
              value={editSectionName}
              onChangeText={setEditSectionName}
              autoFocus
            />
            <TouchableOpacity style={[styles.confirmBtn, styles.depositBtn]} onPress={handleRenameSection}>
              <Text style={styles.confirmBtnText}>Save Name</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[styles.confirmBtn, styles.deleteBtn]} onPress={deleteSection}>
              <Trash2 size={20} color="white" />
              <Text style={styles.confirmBtnText}>Delete Bucket</Text>
            </TouchableOpacity>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </SafeAreaViewContext>
  );
}

// --- STYLES ---
const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f3f4f6' },
  headerContainer: { 
    paddingHorizontal: 24, 
    // Reduced padding to shift upward as requested previously
    paddingTop: Platform.OS === 'android' ? 35 : 15, 
    paddingBottom: 30, 
    backgroundColor: '#ffffff', 
    borderBottomLeftRadius: 24, 
    borderBottomRightRadius: 24, 
    shadowColor: '#000', 
    shadowOffset: { width: 0, height: 2 }, 
    shadowOpacity: 0.05, 
    shadowRadius: 10, 
    elevation: 5, 
    marginBottom: 20, 
  },
  headerTopRow: {
    flexDirection: 'row',
    justifyContent: 'center', 
    alignItems: 'center',
    marginBottom: 8,
    position: 'relative', 
    width: '100%',
  },
  resetButton: {
    position: 'absolute',
    right: 0,
    padding: 8,
  },
  appTitle: { fontSize: 16, fontWeight: '600', color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 1 },
  totalBalanceCard: { alignItems: 'center' },
  balanceLabelRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 4 },
  balanceLabel: { fontSize: 14, color: '#6b7280' },
  filterButton: { padding: 4, backgroundColor: '#f3f4f6', borderRadius: 12 },
  totalAmount: { fontSize: 40, fontWeight: '800', color: '#111827' },
  
  filterRowItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f3f4f6'
  },
  filterRowText: { fontSize: 16, color: '#374151', fontWeight: '500' },

  listContainer: { paddingHorizontal: 20 },
  sectionCard: { backgroundColor: 'white', borderRadius: 16, padding: 20, marginBottom: 16, shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.05, shadowRadius: 4, elevation: 3 },
  sectionCardDisabled: { opacity: 0.8, backgroundColor: '#f9fafb', borderWidth: 1, borderColor: '#e5e7eb', elevation: 0 },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  sectionName: { fontSize: 16, fontWeight: '600', color: '#374151' },
  iconButton: { padding: 4 },
  cardBody: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  amountContainer: { flexDirection: 'row', alignItems: 'baseline' },
  currencyPrefix: { fontSize: 18, fontWeight: '500', color: '#9ca3af', marginRight: 2 },
  sectionAmount: { fontSize: 28, fontWeight: '700', color: '#111827' },
  actionRow: { flexDirection: 'row', gap: 12 },
  actionButton: { width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 4, elevation: 5 },
  plusButton: { backgroundColor: '#111827' },
  minusButton: { backgroundColor: '#ef4444' },
  addNewTypeBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 10, padding: 16, backgroundColor: 'white', marginHorizontal: 20, borderRadius: 12, borderWidth: 1, borderColor: '#e5e7eb', borderStyle: 'dashed' },
  addNewTypeText: { marginLeft: 8, fontSize: 16, fontWeight: '600', color: '#3b82f6' },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  modalContent: { backgroundColor: '#ffffff', borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 24, height: '80%', shadowColor: '#000', shadowOffset: { width: 0, height: -4 }, shadowOpacity: 0.1, shadowRadius: 10, elevation: 20 },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 24 },
  modalTitle: { fontSize: 22, fontWeight: 'bold', color: '#111827' },
  modalSubtitle: { fontSize: 14, color: '#6b7280', marginTop: 2 },
  closeButton: { padding: 4, backgroundColor: '#f3f4f6', borderRadius: 20 },
  label: { fontSize: 14, fontWeight: '600', color: '#374151', marginBottom: 8, textTransform: 'uppercase' },
  inputWrapper: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#f9fafb', borderRadius: 12, borderWidth: 1, borderColor: '#e5e7eb', paddingHorizontal: 16, marginBottom: 24 },
  inputPrefix: { fontSize: 24, fontWeight: '500', color: '#9ca3af', marginRight: 8 },
  inputSuffix: { fontSize: 18, fontWeight: '500', color: '#9ca3af', marginLeft: 4, marginRight: 8 },
  mainInput: { flex: 1, fontSize: 32, fontWeight: '700', color: '#111827', paddingVertical: 16 },
  simpleInput: { backgroundColor: '#f9fafb', borderWidth: 1, borderColor: '#e5e7eb', borderRadius: 12, padding: 16, fontSize: 18, color: '#111827', marginBottom: 24 },
  toggleRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', backgroundColor: '#f9fafb', padding: 16, borderRadius: 12, marginBottom: 20, borderWidth: 1, borderColor: '#f3f4f6' },
  toggleLabel: { fontSize: 16, fontWeight: '500', color: '#374151' },
  withdrawRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 12, gap: 12 },
  withdrawInputWrapper: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff1f2', borderRadius: 12, borderWidth: 1, borderColor: '#fecdd3', paddingHorizontal: 16 },
  withdrawPrefix: { fontSize: 18, fontWeight: '600', color: '#ef4444', marginRight: 8 },
  withdrawInput: { flex: 1, fontSize: 20, fontWeight: '700', color: '#991b1b', paddingVertical: 12 },
  removeBtn: { padding: 12, backgroundColor: '#fee2e2', borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  addWithdrawItemBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', padding: 14, backgroundColor: '#eff6ff', borderRadius: 12, borderWidth: 1, borderColor: '#bfdbfe', borderStyle: 'dashed', marginBottom: 20 },
  addWithdrawItemText: { marginLeft: 8, fontSize: 16, fontWeight: '600', color: '#3b82f6' },
  totalRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingTop: 16, borderTopWidth: 1, borderColor: '#e5e7eb', marginBottom: 8 },
  totalLabel: { fontSize: 16, fontWeight: '600', color: '#374151' },
  totalValue: { fontSize: 24, fontWeight: '800', color: '#ef4444' },
  splitSection: { marginBottom: 20, backgroundColor: '#f8fafc', padding: 16, borderRadius: 16, borderWidth: 1, borderColor: '#e2e8f0' },
  hintText: { fontSize: 13, color: '#64748b', marginBottom: 16, lineHeight: 20 },
  splitRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  splitName: { fontSize: 15, color: '#334155', fontWeight: '500', flex: 1, marginRight: 10 },
  splitInputContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'white', borderRadius: 8, borderWidth: 1, borderColor: '#cbd5e1', paddingHorizontal: 12, width: 100 },
  splitInput: { flex: 1, paddingVertical: 8, textAlign: 'right', fontSize: 16, fontWeight: '600', color: '#0f172a' },
  percentSign: { color: '#94a3b8', marginLeft: 4, fontSize: 14, fontWeight: '500' },
  splitSummary: { marginTop: 12, paddingTop: 12, borderTopWidth: 1, borderColor: '#e2e8f0' },
  summaryLabel: { fontSize: 14, fontWeight: '600', color: '#64748b' },
  confirmBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', padding: 18, borderRadius: 14, shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 8, elevation: 5, marginTop: 8 },
  depositBtn: { backgroundColor: '#111827' },
  withdrawBtn: { backgroundColor: '#ef4444' },
  deleteBtn: { backgroundColor: '#dc2626', marginTop: 16 },
  confirmBtnText: { color: 'white', fontSize: 16, fontWeight: '700', marginLeft: 8 },
  
  // Transfer Styles
  transferRow: { marginBottom: 8 },
  transferBoxReadOnly: { backgroundColor: '#f3f4f6', padding: 16, borderRadius: 12, borderWidth: 1, borderColor: '#e5e7eb' },
  transferBoxText: { fontSize: 16, color: '#374151', fontWeight: '600' },
  targetOption: { paddingHorizontal: 16, paddingVertical: 12, backgroundColor: 'white', borderRadius: 12, borderWidth: 1, borderColor: '#e5e7eb', minWidth: 100, alignItems: 'center' },
  targetOptionActive: { backgroundColor: '#eff6ff', borderColor: '#3b82f6', borderWidth: 2 },
  targetOptionText: { fontSize: 14, color: '#6b7280', fontWeight: '500' },
  targetOptionTextActive: { color: '#3b82f6', fontWeight: '700' },
  transferInputsRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 20 },
});